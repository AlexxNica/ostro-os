# ex:ts=4:sw=4:sts=4:et
# -*- tab-width: 4; c-basic-offset: 4; indent-tabs-mode: nil -*-
#
# BitBake 'Event' implementation
#
# Caching of bitbake variables before task execution

# Copyright (C) 2006        Richard Purdie

# but small sections based on code from bin/bitbake:
# Copyright (C) 2003, 2004  Chris Larson
# Copyright (C) 2003, 2004  Phil Blundell
# Copyright (C) 2003 - 2005 Michael 'Mickey' Lauer
# Copyright (C) 2005        Holger Hans Peter Freyther
# Copyright (C) 2005        ROAD GmbH
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.


import os
import logging
from collections import defaultdict
import bb.data
import bb.utils

logger = logging.getLogger("BitBake.Cache")

try:
    import cPickle as pickle
except ImportError:
    import pickle
    logger.info("Importing cPickle failed. Falling back to a very slow implementation.")

__cache_version__ = "132"

class Cache:
    """
    BitBake Cache implementation
    """
    def __init__(self, data):


        self.cachedir = bb.data.getVar("CACHE", data, True)
        self.clean = {}
        self.checked = {}
        self.depends_cache = {}
        self.data = None
        self.data_fn = None
        self.cacheclean = True

        if self.cachedir in [None, '']:
            self.has_cache = False
            logger.info("Not using a cache. Set CACHE = <directory> to enable.")
            return

        self.has_cache = True
        self.cachefile = os.path.join(self.cachedir, "bb_cache.dat")

        logger.debug(1, "Using cache in '%s'", self.cachedir)
        bb.utils.mkdirhier(self.cachedir)

        # If any of configuration.data's dependencies are newer than the
        # cache there isn't even any point in loading it...
        newest_mtime = 0
        deps = bb.data.getVar("__depends", data)

        old_mtimes = [old_mtime for f, old_mtime in deps]
        old_mtimes.append(newest_mtime)
        newest_mtime = max(old_mtimes)

        if bb.parse.cached_mtime_noerror(self.cachefile) >= newest_mtime:
            try:
                p = pickle.Unpickler(file(self.cachefile, "rb"))
                self.depends_cache, version_data = p.load()
                if version_data['CACHE_VER'] != __cache_version__:
                    raise ValueError('Cache Version Mismatch')
                if version_data['BITBAKE_VER'] != bb.__version__:
                    raise ValueError('Bitbake Version Mismatch')
            except EOFError:
                logger.info("Truncated cache found, rebuilding...")
                self.depends_cache = {}
            except:
                logger.info("Invalid cache found, rebuilding...")
                self.depends_cache = {}
        else:
            if os.path.isfile(self.cachefile):
                logger.info("Out of date cache found, rebuilding...")

    def getVar(self, var, fn, exp = 0):
        """
        Gets the value of a variable
        (similar to getVar in the data class)

        There are two scenarios:
          1. We have cached data - serve from depends_cache[fn]
          2. We're learning what data to cache - serve from data
             backend but add a copy of the data to the cache.
        """
        if fn in self.clean:
            return self.depends_cache[fn].get(var)

        self.depends_cache.setdefault(fn, {})

        if fn != self.data_fn:
            # We're trying to access data in the cache which doesn't exist
            # yet setData hasn't been called to setup the right access. Very bad.
            logger.error("data_fn %s and fn %s don't match", self.data_fn, fn)

        self.cacheclean = False
        result = bb.data.getVar(var, self.data, exp)
        if result is not None:
            self.depends_cache[fn][var] = result
        return result

    def setData(self, virtualfn, fn, data):
        """
        Called to prime bb_cache ready to learn which variables to cache.
        Will be followed by calls to self.getVar which aren't cached
        but can be fulfilled from self.data.
        """
        self.data_fn = virtualfn
        self.data = data

        # Make sure __depends makes the depends_cache
        # If we're a virtual class we need to make sure all our depends are appended
        # to the depends of fn.
        depends = self.getVar("__depends", virtualfn) or set()
        self.depends_cache.setdefault(fn, {})
        if "__depends" not in self.depends_cache[fn] or not self.depends_cache[fn]["__depends"]:
            self.depends_cache[fn]["__depends"] = depends
        else:
            self.depends_cache[fn]["__depends"].update(depends)

        # Make sure the variants always make it into the cache too
        self.getVar('__VARIANTS', virtualfn, True)

        self.depends_cache[virtualfn]["CACHETIMESTAMP"] = bb.parse.cached_mtime(fn)

    def virtualfn2realfn(self, virtualfn):
        """
        Convert a virtual file name to a real one + the associated subclass keyword
        """

        fn = virtualfn
        cls = ""
        if virtualfn.startswith('virtual:'):
            cls = virtualfn.split(':', 2)[1]
            fn = virtualfn.replace('virtual:' + cls + ':', '')
        return (fn, cls)

    def realfn2virtual(self, realfn, cls):
        """
        Convert a real filename + the associated subclass keyword to a virtual filename
        """
        if cls == "":
            return realfn
        return "virtual:" + cls + ":" + realfn

    def loadDataFull(self, virtualfn, appends, cfgData):
        """
        Return a complete set of data for fn.
        To do this, we need to parse the file.
        """

        (fn, cls) = self.virtualfn2realfn(virtualfn)

        logger.debug(1, "Parsing %s (full)", fn)

        bb_data = self.load_bbfile(fn, appends, cfgData)
        return bb_data[cls]

    def loadData(self, fn, appends, cfgData, cacheData):
        """
        Load a subset of data for fn.
        If the cached data is valid we do nothing,
        To do this, we need to parse the file and set the system
        to record the variables accessed.
        Return the cache status and whether the file was skipped when parsed
        """
        skipped = 0
        virtuals = 0

        if fn not in self.checked:
            self.cacheValidUpdate(fn)

        if self.cacheValid(fn):
            multi = self.getVar('__VARIANTS', fn, True)
            for cls in (multi or "").split() + [""]:
                virtualfn = self.realfn2virtual(fn, cls)
                if self.depends_cache[virtualfn].get("__SKIPPED"):
                    skipped += 1
                    logger.debug(1, "Skipping %s", virtualfn)
                    continue
                self.handle_data(virtualfn, cacheData)
                virtuals += 1
            return True, skipped, virtuals

        logger.debug(1, "Parsing %s", fn)

        bb_data = self.load_bbfile(fn, appends, cfgData)

        for data in bb_data:
            virtualfn = self.realfn2virtual(fn, data)
            self.setData(virtualfn, fn, bb_data[data])
            if self.getVar("__SKIPPED", virtualfn):
                skipped += 1
                logger.debug(1, "Skipping %s", virtualfn)
            else:
                self.handle_data(virtualfn, cacheData)
                virtuals += 1
        return False, skipped, virtuals

    def cacheValid(self, fn):
        """
        Is the cache valid for fn?
        Fast version, no timestamps checked.
        """
        # Is cache enabled?
        if not self.has_cache:
            return False
        if fn in self.clean:
            return True
        return False

    def cacheValidUpdate(self, fn):
        """
        Is the cache valid for fn?
        Make thorough (slower) checks including timestamps.
        """
        # Is cache enabled?
        if not self.has_cache:
            return False

        self.checked[fn] = ""

        # Pretend we're clean so getVar works
        self.clean[fn] = ""

        # File isn't in depends_cache
        if not fn in self.depends_cache:
            logger.debug(2, "Cache: %s is not cached", fn)
            self.remove(fn)
            return False

        mtime = bb.parse.cached_mtime_noerror(fn)

        # Check file still exists
        if mtime == 0:
            logger.debug(2, "Cache: %s no longer exists", fn)
            self.remove(fn)
            return False

        # Check the file's timestamp
        if mtime != self.getVar("CACHETIMESTAMP", fn, True):
            logger.debug(2, "Cache: %s changed", fn)
            self.remove(fn)
            return False

        # Check dependencies are still valid
        depends = self.getVar("__depends", fn, True)
        if depends:
            for f, old_mtime in depends:
                fmtime = bb.parse.cached_mtime_noerror(f)
                # Check if file still exists
                if old_mtime != 0 and fmtime == 0:
                    self.remove(fn)
                    return False

                if (fmtime != old_mtime):
                    logger.debug(2, "Cache: %s's dependency %s changed", fn, f)
                    self.remove(fn)
                    return False

        if not fn in self.clean:
            self.clean[fn] = ""

        invalid = False
        # Mark extended class data as clean too
        multi = self.getVar('__VARIANTS', fn, True)
        for cls in (multi or "").split():
            virtualfn = self.realfn2virtual(fn, cls)
            self.clean[virtualfn] = ""
            if not virtualfn in self.depends_cache:
                logger.debug(2, "Cache: %s is not cached", virtualfn)
                invalid = True

        # If any one of the varients is not present, mark cache as invalid for all
        if invalid:
            for cls in (multi or "").split():
                virtualfn = self.realfn2virtual(fn, cls)
                if virtualfn in self.clean:
                    logger.debug(2, "Cache: Removing %s from cache", virtualfn)
                    del self.clean[virtualfn]
            if fn in self.clean:
                logger.debug(2, "Cache: Marking %s as not clean", fn)
                del self.clean[fn]
            return False

        return True

    def remove(self, fn):
        """
        Remove a fn from the cache
        Called from the parser in error cases
        """
        if fn in self.depends_cache:
            logger.debug(1, "Removing %s from cache", fn)
            del self.depends_cache[fn]
        if fn in self.clean:
            logger.debug(1, "Marking %s as unclean", fn)
            del self.clean[fn]

    def sync(self):
        """
        Save the cache
        Called from the parser when complete (or exiting)
        """
        import copy

        if not self.has_cache:
            return

        if self.cacheclean:
            logger.debug(2, "Cache is clean, not saving.")
            return

        version_data = {}
        version_data['CACHE_VER'] = __cache_version__
        version_data['BITBAKE_VER'] = bb.__version__

        cache_data = copy.copy(self.depends_cache)
        for fn in self.depends_cache:
            if '__BB_DONT_CACHE' in self.depends_cache[fn] and self.depends_cache[fn]['__BB_DONT_CACHE']:
                logger.debug(2, "Not caching %s, marked as not cacheable", fn)
                del cache_data[fn]
            elif 'PV' in self.depends_cache[fn] and 'SRCREVINACTION' in self.depends_cache[fn]['PV']:
                logger.error("Not caching %s as it had SRCREVINACTION in PV. Please report this bug", fn)
                del cache_data[fn]

        p = pickle.Pickler(file(self.cachefile, "wb" ), -1 )
        p.dump([cache_data, version_data])
        del self.depends_cache

    def mtime(self, cachefile):
        return bb.parse.cached_mtime_noerror(cachefile)

    def handle_data(self, file_name, cacheData):
        """
        Save data we need into the cache
        """

        pn       = self.getVar('PN', file_name, True)
        pe       = self.getVar('PE', file_name, True) or "0"
        pv       = self.getVar('PV', file_name, True)
        if 'SRCREVINACTION' in pv:
            logger.info("Found SRCREVINACTION in PV (%s) or %s. Please report this bug.", pv, file_name)
        pr       = self.getVar('PR', file_name, True)
        dp       = int(self.getVar('DEFAULT_PREFERENCE', file_name, True) or "0")
        depends   = bb.utils.explode_deps(self.getVar("DEPENDS", file_name, True) or "")
        packages  = (self.getVar('PACKAGES', file_name, True) or "").split()
        packages_dynamic = (self.getVar('PACKAGES_DYNAMIC', file_name, True) or "").split()
        rprovides = (self.getVar("RPROVIDES", file_name, True) or "").split()

        cacheData.task_deps[file_name] = self.getVar("_task_deps", file_name)

        # build PackageName to FileName lookup table
        cacheData.pkg_pn[pn].append(file_name)

        cacheData.stamp[file_name] = self.getVar('STAMP', file_name, True)

        cacheData.tasks[file_name] = self.getVar('__BBTASKS', file_name, True)
        for t in cacheData.tasks[file_name]:
            cacheData.basetaskhash[file_name + "." + t] = self.getVar("BB_BASEHASH_task-%s" % t, file_name, True)

        # build FileName to PackageName lookup table
        cacheData.pkg_fn[file_name] = pn
        cacheData.pkg_pepvpr[file_name] = (pe, pv, pr)
        cacheData.pkg_dp[file_name] = dp

        provides = [pn]
        for provide in (self.getVar("PROVIDES", file_name, True) or "").split():
            if provide not in provides:
                provides.append(provide)

        # Build forward and reverse provider hashes
        # Forward: virtual -> [filenames]
        # Reverse: PN -> [virtuals]
        cacheData.fn_provides[file_name] = provides
        for provide in provides:
            cacheData.providers[provide].append(file_name)
            if not provide in cacheData.pn_provides[pn]:
                cacheData.pn_provides[pn].append(provide)

        for dep in depends:
            if not dep in cacheData.deps[file_name]:
                cacheData.deps[file_name].append(dep)
            if not dep in cacheData.all_depends:
                cacheData.all_depends.append(dep)

        # Build reverse hash for PACKAGES, so runtime dependencies
        # can be be resolved (RDEPENDS, RRECOMMENDS etc.)
        for package in packages:
            cacheData.packages[package].append(file_name)
            rprovides += (self.getVar("RPROVIDES_%s" % package, file_name, 1) or "").split()

        for package in packages_dynamic:
            cacheData.packages_dynamic[package].append(file_name)

        for rprovide in rprovides:
            cacheData.rproviders[rprovide].append(file_name)

        # Build hash of runtime depends and rececommends
        rdepends = bb.utils.explode_deps(self.getVar('RDEPENDS', file_name, True) or "")
        rrecommends = bb.utils.explode_deps(self.getVar('RRECOMMENDS', file_name, True) or "")
        for package in packages + [pn]:
            rdeps_pkg = bb.utils.explode_deps(self.getVar('RDEPENDS_%s' % package, file_name, True) or "")
            cacheData.rundeps[file_name][package] = rdepends + rdeps_pkg
            rrecs_pkg = bb.utils.explode_deps(self.getVar('RDEPENDS_%s' % package, file_name, True) or "")
            cacheData.runrecs[file_name][package] = rrecommends + rrecs_pkg

        # Collect files we may need for possible world-dep
        # calculations
        if not self.getVar('BROKEN', file_name, True) and not self.getVar('EXCLUDE_FROM_WORLD', file_name, True):
            cacheData.possible_world.append(file_name)

        cacheData.hashfn[file_name] = self.getVar('BB_HASHFILENAME', file_name, True)

        # Touch this to make sure its in the cache
        self.getVar('__BB_DONT_CACHE', file_name, True)
        self.getVar('__VARIANTS', file_name, True)

    def load_bbfile(self, bbfile, appends, config):
        """
        Load and parse one .bb build file
        Return the data and whether parsing resulted in the file being skipped
        """
        chdir_back = False

        from bb import data, parse

        # expand tmpdir to include this topdir
        data.setVar('TMPDIR', data.getVar('TMPDIR', config, 1) or "", config)
        bbfile_loc = os.path.abspath(os.path.dirname(bbfile))
        oldpath = os.path.abspath(os.getcwd())
        parse.cached_mtime_noerror(bbfile_loc)
        bb_data = data.init_db(config)
        # The ConfHandler first looks if there is a TOPDIR and if not
        # then it would call getcwd().
        # Previously, we chdir()ed to bbfile_loc, called the handler
        # and finally chdir()ed back, a couple of thousand times. We now
        # just fill in TOPDIR to point to bbfile_loc if there is no TOPDIR yet.
        if not data.getVar('TOPDIR', bb_data):
            chdir_back = True
            data.setVar('TOPDIR', bbfile_loc, bb_data)
        try:
            if appends:
                data.setVar('__BBAPPEND', " ".join(appends), bb_data)
            bb_data = parse.handle(bbfile, bb_data) # read .bb data
            if chdir_back: os.chdir(oldpath)
            return bb_data
        except:
            if chdir_back: os.chdir(oldpath)
            raise

def init(cooker):
    """
    The Objective: Cache the minimum amount of data possible yet get to the
    stage of building packages (i.e. tryBuild) without reparsing any .bb files.

    To do this, we intercept getVar calls and only cache the variables we see
    being accessed. We rely on the cache getVar calls being made for all
    variables bitbake might need to use to reach this stage. For each cached
    file we need to track:

    * Its mtime
    * The mtimes of all its dependencies
    * Whether it caused a parse.SkipPackage exception

    Files causing parsing errors are evicted from the cache.

    """
    return Cache(cooker.configuration.data)



#============================================================================#
# CacheData
#============================================================================#
class CacheData:
    """
    The data structures we compile from the cached data
    """

    def __init__(self):
        """
        Direct cache variables
        (from Cache.handle_data)
        """
        self.providers   = defaultdict(list)
        self.rproviders = defaultdict(list)
        self.packages = defaultdict(list)
        self.packages_dynamic = defaultdict(list)
        self.possible_world = []
        self.pkg_pn = defaultdict(list)
        self.pkg_fn = {}
        self.pkg_pepvpr = {}
        self.pkg_dp = {}
        self.pn_provides = defaultdict(list)
        self.fn_provides = {}
        self.all_depends = []
        self.deps = defaultdict(list)
        self.rundeps = defaultdict(lambda: defaultdict(list))
        self.runrecs = defaultdict(lambda: defaultdict(list))
        self.task_queues = {}
        self.task_deps = {}
        self.stamp = {}
        self.preferred = {}
        self.tasks = {}
        self.basetaskhash = {}
        self.hashfn = {}

        """
        Indirect Cache variables
        (set elsewhere)
        """
        self.ignored_dependencies = []
        self.world_target = set()
        self.bbfile_priority = {}
        self.bbfile_config_priorities = []
