KBRANCH_atom-pc  = "yocto/standard/common-pc/atom-pc"
KBRANCH_routerstationpro = "yocto/standard/routerstationpro"
KBRANCH_mpc8315e-rdb = "yocto/standard/fsl-mpc8315e-rdb"
KBRANCH_beagleboard = "yocto/standard/beagleboard"

# temporary until 3.0 tree is updated to have machine mapping
KMACHINE_mpc8315e-rdb = "fsl-mpc8315e-rdb"

SRCREV_machine_atom-pc ?= "afdda882f902dd28693cd8701a7d497958290f09"
SRCREV_machine_routerstationpro ?= "220d89fcf345ee28fb0cdcf0f33f83b3dc7c460f"
SRCREV_machine_mpc8315e-rdb ?= "83f422f718cf15633cb4c2d309aa041c3c354f65"
SRCREV_machine_beagleboard ?= "8fd5a8eb4067c7032389e82d54f0e54e1e27f78c"

COMPATIBLE_MACHINE_mpc8315e-rdb = "mpc8315e-rdb"
COMPATIBLE_MACHINE_routerstationpro = "routerstationpro"
COMPATIBLE_MACHINE_beagleboard = "beagleboard"
COMPATIBLE_MACHINE_atom-pc = "atom-pc"
