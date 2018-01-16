#########################################################################
#
# Makefile used for building application.
#
# The default target (all) builds application in three formats :
#   *.rec : Image in S-record format.
#   *.bin : Image in binary format.
#   *.elf : Image in ELF format.
#   *.map : Linker generated map file.
#   *.dis : Disassembly of image.
#   *.sym : Symbols.
#
# Other targets are :
#   clean :	Deletes all files generated by makefile.
#
#########################################################################

CONFIG_FILE ?= .config

-include $(CONFIG_FILE)

-include $(CONFIG_MODEL_FILE)

PROJ   ?= MST9U
PARA   ?= 0
# **********************************************
# Build Options
# **********************************************
# Version: Debug or Retail
ifeq ($(CHIP_FAMILY),MST9U)
VERSION  ?= Retail
else
  VERSION  ?= Debug
endif

# Image name
AP_NAME = AP
BL_NAME = BL
AP_COMPRESS_NAME = AP_C
ifeq ($(HP_MODEL_NAME),$(filter $(HP_MODEL_NAME),HP_SPECTRE32))
MERGE_NAME = $(HP_MODEL_NAME)_$(PANEL_TYPE)
else ifeq ($(HP_MODEL_NAME),$(filter $(HP_MODEL_NAME),HP_S240t HP_S240uw))
MERGE_NAME = HP_S240uj_$(PANEL_TYPE)_$(INFO_VERSION)_$(FW_DATE)_$(BOARD_TYPE_SEL)
else ifeq ($(HP_MODEL_NAME),$(filter $(HP_MODEL_NAME),HP_Envy32g))
MERGE_NAME = $(HP_MODEL_NAME)_$(PANEL_TYPE)_$(INFO_VERSION)_$(FW_DATE)_$(BOARD_TYPE_SEL)
else ifeq ($(HP_MODEL_NAME),$(filter $(HP_MODEL_NAME),HP_Pavilion32))
MERGE_NAME = $(HP_MODEL_NAME)_$(PANEL_TYPE)_$(INFO_VERSION)_$(FW_DATE)_$(BOARD_TYPE_SEL)
else ifeq ($(HP_MODEL_NAME),$(filter $(HP_MODEL_NAME),HP_Envy27))
MERGE_NAME = $(HP_MODEL_NAME)_$(PANEL_TYPE)_$(INFO_VERSION)_$(FW_DATE)_$(BOARD_TYPE_SEL)
else ifeq ($(HP_MODEL_NAME),$(filter $(HP_MODEL_NAME),HP_Envy27s))
MERGE_NAME = $(HP_MODEL_NAME)_$(PANEL_TYPE)_$(INFO_VERSION)_$(FW_DATE)_$(BOARD_TYPE_SEL)
else
MERGE_NAME = MERGE
endif
RES_NAME = RES

ifeq ($(BUILD_TARGET),MAIN_AP_SYSTEM)
_BL_SIZE = $(firstword $(shell du -b $(BINPATH)_BLOADER/MERGE.bin))
BL_SIZE = $(shell _BL_SIZE1=$(_BL_SIZE); _BL_SIZE2=131072; printf '0x%X' $$((_BL_SIZE1-_BL_SIZE2)))
endif

# **********************************************
# Tool Chain
# **********************************************
ifeq ($(OS_TYPE),nos_aeon)
CROSSCOMPILE = aeon-
CORSSCOMPILE_VER =
AEON_FLAG	= -march=$(AEON_TYPE) -mhard-div -mhard-mul -EL -mredzone-size=4
else
$(error "NOT supported OS_TYPE, Please config OS_TYPE=nos_aeon")
endif
# AEON_FLAG   = -march=aeon1 -mhard-div -mhard-mul -fno-delayed-branch -minsert-nop-before-branch

ifeq ($(PARA), 1)
CC	= cpptestscan --cpptestscanProjectName=UTProject $(CROSSCOMPILE)gcc $(CROSSCOMPILE_VER)
CPP     = cpptestscan --cpptestscanProjectName=UTProject $(CROSSCOMPILE)cpp
LD	= cpptestscan --cpptestscanProjectName=UTProject $(CROSSCOMPILE)ld
else
CC	= $(CROSSCOMPILE)gcc $(CROSSCOMPILE_VER)
CPP     = $(CROSSCOMPILE)cpp
LD	= $(CROSSCOMPILE)ld
endif
OBJCOPY = $(CROSSCOMPILE)objcopy
OBJDUMP = $(CROSSCOMPILE)objdump
SIZE	= $(CROSSCOMPILE)size
AR	= $(CROSSCOMPILE)ar
NM	= $(CROSSCOMPILE)nm

AWK     = /bin/gawk
UNAME   = $(shell uname)

ifeq ($(shell uname -s), Linux)
FLINT   = scripts/flint
REALPATH= echo
else
FLINT   = scripts/LINT-NT.EXE
REALPATH:= cygpath -w
endif

# **********************************************
# Directories
# **********************************************
PREFIXDIR?=
ROOT	= .
BINDIR	= ./$(PREFIXDIR)/Bin_$(HP_MODEL_NAME)
BINPATH = $(BINDIR)
OBJDIR	= ./$(PREFIXDIR)/Obj_$(HP_MODEL_NAME)
OBJPATH = $(OBJDIR)
LZSSDIR = ./scripts/lzss
MSCOMPDIR = ./scripts/util


ifeq ($(CHIP_FAMILY),MST9U)
    COREDIR   ?= ./core
    COREDIR_F ?= $(CURDIR)/core
#move to later place, this is a patch
#ifeq ($(AEON_TYPE),aeonR2)
#    IMGINFO_OFFSET = 70016
#else
#    IMGINFO_OFFSET = 4352
#endif
endif

ifeq ($(VERIFY_GE),y)
    CC_MTOPTS += -DVERIFY_GE=1
    VERIFY_GE_FLAG = VERIFY_GE=y
else
    CC_MTOPTS += -DVERIFY_GE=0
    VERIFY_GE_FLAG = VERIFY_GE=n
endif

ifeq ($(MST9U_FPGA),y)
    CC_MTOPTS += -DMST9U_FPGA=1
	MST9U_FPGA_FLAG = MST9U_FPGA=y
else
	MST9U_FPGA_FLAG =
endif

ifeq ($(AUTOBOOT),1)
    CC_MTOPTS += -DAUTOBOOT=1 -DAUTOBOOTCL=$(CL)
endif

ifeq ($(BUILD_TARGET),ORGINAL_ALL_SYSTEM)
    CC_MTOPTS += -DORGINAL_ALL_MERGE=1
    CC_MTOPTS += -DBLOADER=0
else
    CC_MTOPTS += -DORGINAL_ALL_MERGE=0
    ifeq ($(BUILD_TARGET),BLOADER_SYSTEM)
        CC_MTOPTS += -DBLOADER=1
    else
        CC_MTOPTS += -DBLOADER=0
    endif
endif

ifeq ($(SECURE_BOOT),1)
    CC_MTOPTS += -DSECURE_BOOT=1
else
    CC_MTOPTS += -DSECURE_BOOT=0
endif

# Source files

 SRC_FILE = \
	    ./core/api/utl/NoOS.c                    \


# Driver BSP header file


       
# Add "Header (include) file" directories here ...
ifeq ($(OS_TYPE),nos_aeon)
INC_DIR   = \
		-I$(ROOT)/include                                   \
		-I$(BOOTDIR)					                    \
		-I$(COREDIR)/api/include                            \
		-I$(COREDIR)/driver/sys/include                     \
		-I$(DRV_BSP_INC)									\

endif

ifeq ($(DEBUG_FUN_SEL),DEBUG_FUN_ENABLE)
    CC_MTOPTS += -DENABLE_MSTV_UART_DEBUG=1 -DUSE_SW_I2C=1 -DCOMB_3D -DBOOTLOADER_BANK_NUM
else
    CC_MTOPTS += -DENABLE_MSTV_UART_DEBUG=0 -DUSE_SW_I2C=1 -DCOMB_3D -DBOOTLOADER_BANK_NUM
endif

WARN_FLAGS = -Wall -Wextra -Wcast-align -Wpointer-arith -Wstrict-prototypes -Winline -Wundef -Wno-format -Wshadow
#ifeq ($(OS_TYPE),linux)
#WARN_FLAGS = -Wall -Wextra -Wcast-align -Wpointer-arith -Wstrict-prototypes -Winline -Wundef -Wno-format -Wshadow
#else
#ifeq ($(OS_TYPE),nos_mips)
#WARN_FLAGS = -Wall -Wextra -Wcast-align -Wpointer-arith -Wstrict-prototypes -Winline -Wundef -Wno-format -Wshadow

YOGA_GLOBAL_CFLAGS = -pipe -fno-exceptions -ffunction-sections $(WARN_FLAGS)

include project/build/FILES_$(PROJ).mk

# Add PQ directories
ifeq ($(PROJ), R2_MST9U3_HP)
PQ_DIR = $(MONITOR_PATH_PQ)/MST9U3
else
PQ_DIR = $(MONITOR_PATH_PQ)/MST9U2
endif

ifeq ($(CHIP_FAMILY),MST9U)
ifeq ($(AEON_TYPE),aeonR2)
#This is a patch, move to here
#IMGINFO_OFFSET = 70016
IMGINFO_OFFSET = 4352
LDSCRIPT_SRC ?= project/loader/target.ld
DRV_BSP_INC   = $(COREDIR)/drv_bsp/MST9U_nos_r2/include

#Full path variables for library-install
DRV_BSP_INC_F = $(COREDIR_F)/drv_bsp/MST9U_nos_r2/include
DRV_BSP_LIB_F = $(COREDIR_F)/drv_bsp/MST9U_nos_r2/lib
LIB_PRANA_PATH_F = $(COREDIR_F)/lib/MST9U
LIB_PRANA_INC_F  = $(COREDIR_F)/lib/MST9U/include

INC_DIR += -I$(COREDIR)/lib/MST9U/include
endif
endif


# -D__CREATE_TIMER_WITH_INTERVAL_0__
# **********************************************
# Image file names
# **********************************************
AP_BIN = $(BINPATH)/$(AP_NAME).bin
###AP_BIN2= $(BINPATH)/$(AP_NAME)_2.bin
APC_BIN = $(BINPATH)/$(AP_COMPRESS_NAME).bin
AP_ELF = $(BINPATH)/$(AP_NAME).elf
AP_MAP = $(BINPATH)/$(AP_NAME).map
AP_DIS = $(BINPATH)/$(AP_NAME).dis
AP_SYM = $(BINPATH)/$(AP_NAME).sym
AP_OBJ = $(OBJPATH)/$(AP_NAME).o

MERGE_BIN = $(BINPATH)/$(MERGE_NAME).bin
#MERGE_ELF = $(BINPATH)/$(MERGE_NAME).elf
MERGE_DIS = $(BINPATH)/$(MERGE_NAME).dis
MERGE_MAP = $(BINPATH)/$(MERGE_NAME).map
MERGE_BIN_2 = $(BINPATH)/$(MERGE_NAME)_2.bin
###HK51_BOOT = $(BINPATH)/$(MERGE_NAME).bin

FULL_BIN = $(BINPATH)/$(MERGE_NAME)_FULL.bin
MERGE_EDID_BIN = $(BINPATH)/$(MERGE_NAME)_EDID_HDCP.bin

ifeq ($(CHIP_FAMILY),MST9U) 
	ifeq ($(DEBUG_FUN_SEL),DEBUG_FUN_ENABLE)
		PM_BIN = $(ROOT)/boot/sboot/bin/$(HP_MODEL_NAME)/$(BOARD_TYPE_SEL)/$(KEY_TYPE_SEL)/Debug/PM.bin
	else
		PM_BIN = $(ROOT)/boot/sboot/bin/$(HP_MODEL_NAME)/$(BOARD_TYPE_SEL)/$(KEY_TYPE_SEL)/PM.bin
	endif
else
	PM_BIN = $(ROOT)/boot/sboot/bin/PM/$(CHIP_FAMILY)/PM.bin
endif
#PM_BIN_SIZE = 65536
PM_BIN_SIZE = $(shell stat -c %s $(PM_BIN))

RES_BIN = $(BINPATH)/$(RES_NAME).bin
DPOUT_BIN = $(ROOT)/boot/sboot/bin/$(HP_MODEL_NAME)/$(BOARD_TYPE_SEL)/daisy_chain.bin
GEN_BIN_SIZE ?= VAR
BIN_FULLSIZE ?= 200000

DP_EDIDBin = $(ROOT)/boot/sboot/bin/$(HP_MODEL_NAME)/$(BOARD_TYPE_SEL)/HP_DP_EDID.bin
DP2_EDIDBin = $(ROOT)/boot/sboot/bin/$(HP_MODEL_NAME)/$(BOARD_TYPE_SEL)/HP_DP2_EDID.bin 
BLANK768Bin = $(ROOT)/boot/sboot/bin/$(HP_MODEL_NAME)/$(BOARD_TYPE_SEL)/EDID_BLANK768.bin
BLANK896Bin = $(ROOT)/boot/sboot/bin/$(HP_MODEL_NAME)/$(BOARD_TYPE_SEL)/EDID_BLANK896.bin
MHL1_EDIDBin = $(ROOT)/boot/sboot/bin/$(HP_MODEL_NAME)/$(BOARD_TYPE_SEL)/HP_MHL1_EDID.bin 
MHL2_EDIDBin = $(ROOT)/boot/sboot/bin/$(HP_MODEL_NAME)/$(BOARD_TYPE_SEL)/HP_MHL2_EDID.bin 
HDCPKEY22Bin = $(ROOT)/boot/sboot/bin/$(HP_MODEL_NAME)/$(BOARD_TYPE_SEL)/HDCP22_Key_4K.bin
BLANK4KBin = $(ROOT)/boot/sboot/bin/$(HP_MODEL_NAME)/$(BOARD_TYPE_SEL)/EDID_BLANK4K.bin
MERGE_EDID2BIN ?= NO
TRIM_SIZE ?= 1FA000
# **********************************************
# Tools
# **********************************************
#SWAP	  = perl $(TOOLS)/byteswap.pl
ifeq ($(BUILD_TARGET),BLOADER_SYSTEM)
    ifeq ($(BIN_FORMAT),COMPRESS)
	BinIDPackFiles = python scripts/PadLoaderCrc_OAD.py
    else
        ifeq ($(BIN_FORMAT),COMPRESS7)
		BinIDPackFiles = python scripts/PadLoaderCrc_OAD.py
        else
		BinIDPackFiles = python scripts/PadLoaderCrc.py
        endif
    endif
else
    ifeq ($(BUILD_TARGET),ORGINAL_ALL_SYSTEM)
        ifeq ($(BIN_FORMAT),COMPRESS)
		BinIDPackFiles = python scripts/BinIDPackFiles_Compress.py
        else
            ifeq ($(BIN_FORMAT),COMPRESS7)
		BinIDPackFiles = python scripts/BinIDPackFiles_Compress.py
            else
		BinIDPackFiles = python scripts/BinIDPackFiles.py
            endif
        endif
    else
        ifeq ($(BIN_FORMAT),COMPRESS)
		BinIDPackFiles = python scripts/BinIDPackFilesForNewMerge_Compress.py
        else
            ifeq ($(BIN_FORMAT),COMPRESS7)
		BinIDPackFiles = python scripts/BinIDPackFilesForNewMerge_Compress.py
            else
		BinIDPackFiles = python scripts/BinIDPackFilesForNewMerge.py
            endif
        endif
    endif
endif
BinIDPackResources = python scripts/BinIDPackResources.py
AddBin = python scripts/Addbin.py

FillBin = python scripts/FillFF2bin.py
MergeEDID2Bin = python scripts/MergeEDID2bin.py
# **********************************************
# Files to be compiled
# **********************************************
SRC_S  = $(filter %.S, $(SRC_FILE))
SRC_C  = $(filter %.c, $(SRC_FILE))
SRC_O  = $(filter %.o,  $(SRC_FILE))
SRC_B  = $(filter %.bin, $(SRC_FILE))

OBJ_S  = ${SRC_S:%.S=$(OBJPATH)/%.o}
OBJ_C  = ${SRC_C:%.c=$(OBJPATH)/%.o}
OBJ_B  = ${SRC_B:%.bin=$(OBJPATH)/%.o}

OBJ	= $(OBJ_C) $(OBJ_B) $(OBJ_S)

BL_SRC_S  = $(filter %.S, $(BL_SRC_FILE))
BL_SRC_C  = $(filter %.c, $(BL_SRC_FILE))
BL_SRC_O  = $(filter %.o,  $(BL_SRC_FILE))
BL_SRC_B  = $(filter %.bin, $(BL_SRC_FILE))

BL_OBJ_S  = ${BL_SRC_S:%.S=$(OBJPATH)/%.o}
BL_OBJ_C  = ${BL_SRC_C:%.c=$(OBJPATH)/%.o}
BL_OBJ_B  = ${BL_SRC_B:%.bin=$(OBJPATH)/%.o}

BL_OBJ	= $(BL_OBJ_C) $(BL_OBJ_B) $(BL_OBJ_S)

SRC	= $(SRC_C) $(BL_SRC_C)

# ***********************************************************************
# Libraries
# ***********************************************************************

# Standard Libraries Path





# **********************************************
# Compiler and linker options
# **********************************************
ifneq ($(OS_TYPE),linux)
YOGA_GLOBAL_LDFLAGS = -msoft-float -g -nostdlib -Wl,--gc-sections -Wl,-static
endif

INCLUDE   = $(INC_DIR)
ifeq ($(PARA), 1)
CC_OPTS0		+=
else
ifneq ($(CROSSCOMPILE),aeon-)
CC_OPTS0		+= -EL
endif
endif

ifeq ($(OS_TYPE),linux)
CC_OPTS0    += -mips32 -Wall -Wpointer-arith -Wstrict-prototypes -msoft-float
CC_OPTS0    += -Winline -Wundef -fno-strict-aliasing -fno-optimize-sibling-calls -ffunction-sections
CC_OPTS0    += -fdata-sections -fno-exceptions -c -G0 -DMSOS_TYPE_LINUX
CC_OPTS0    += -D_REENTRANT -D_FILE_OFFSET_BITS=64
endif


CC_OPTS0  += -c $(INCLUDE) $(AEON_FLAG) $(CC_MTOPTS) $(YOGA_GLOBAL_CFLAGS) $(MALLOC_CFLAGS)
ifeq ($(CHIP_FAMILY),MST9U)
CC_OPTS0  += -Wno-strict-aliasing
endif


ifeq ($(VERSION),Debug)
ifeq ($(OS_TYPE),nos_mips)
CC_OPTS  = $(CC_OPTS0) -g -O0 -gdwarf-2
else
CC_OPTS  = $(CC_OPTS0) -O0 -ggdb
endif
else
CC_OPTS  = $(CC_OPTS0) -O2
endif

ifeq ($(PARA), 1)
LD_OPTS		+=
else
ifneq ($(CROSSCOMPILE),aeon-)
LD_OPTS		+= -EL
endif
endif

ifeq ($(OS_TYPE),nos_mips)
# When ld is used for linking (must specify standard library search path or set SEARCH_DIR in linker script)
ifeq ($(PARA),1)
LD_OPTS += -nostdlib -Wl,--gc-sections -Wl,-static -Wl,-Map,$(AP_MAP)
else
LD_OPTS += -nostdlib -EL -msoft-float -Wl,--gc-sections -Wl,-static -Wl,-Map,$(AP_MAP)
endif
LD_LIB += -lm -lc -L$(OS_LIB_DIR) -T$(LOADER)
else
LD_OPTS += -nostartfiles $(YOGA_GLOBAL_LDFLAGS) $(AEON_FLAG) -LLIB -W1,--gc-sections
LDLIB += -lc -lgcc -lm
endif

ifeq ($(OS_TYPE),linux)
LINT_OPT1 = -e157
endif

# **********************************************
# Rules
# **********************************************
.PHONY : all clean pmsleep lint
.SUFFIXES: .bin .elf .dis .sym .siz

# Project Build


all : $(PROJ)

ifeq ($(OS_TYPE),nos_mips)
$(PROJ): loader setup sboot ap merge lint
	@date
else
ifeq ($(OS_TYPE),nos_aeon)


ifeq ($(BUILD_LIB),y)
.PHONY : $(LIB_PRANA) $(LIB_MXLIB)
$(PROJ): $(LIB_PRANA) $(LIB_MXLIB) loader setup sboot ap merge lint
else
$(PROJ): loader setup sboot ap merge lint
endif
else
$(PROJ): setup ap merge lint
endif
endif



#Note: It's slow to produce .dis file w/o -gdwarf-2 set or original OS source code
ifeq ($(OS_TYPE),linux)
ap: $(AP_ELF)
else
ifeq ($(BUILD_APLIB),y)
ap: $(AP_ELF) $(AP_BIN) $(AP_SYM) monitor_aplib
else
ap: $(AP_ELF) $(AP_BIN) $(AP_SYM)
endif
endif





ifeq ($(BUILD_APLIB),y)
.PHONY: monitor_aplib

monitor_aplib:
	@$(AR) -r $(MONITOR_LIB_FONT) ${MONITOR_FILES_LIB_FONT:%.c=$(OBJPATH)/%.o}
	@$(AR) -r $(MONITOR_LIB_ACE) ${MONITOR_FILES_LIB_ACE:%.c=$(OBJPATH)/%.o}
ifeq ($(PROJ), R2_MST9U3_HP)
	@$(AR) -r $(MONITOR_LIB_EREAD)_MST9U3 ${MONITOR_FILES_LIB_EREAD:%.c=$(OBJPATH)/%.o}
else
	@$(AR) -r $(MONITOR_LIB_EREAD)_MST9U2 ${MONITOR_FILES_LIB_EREAD:%.c=$(OBJPATH)/%.o}
endif
	@$(AR) -r $(MONITOR_LIB_DLC) ${MONITOR_FILES_LIB_DLC:%.c=$(OBJPATH)/%.o}
	@$(AR) -r $(MONITOR_LIB_DPS) ${MONITOR_FILES_LIB_DPS:%.c=$(OBJPATH)/%.o}	
	@$(AR) -r $(MONITOR_LIB_DAISY_CHAIN) ${MONITOR_FILES_LIB_DAISY_CHAIN:%.c=$(OBJPATH)/%.o}	
endif

ifeq ($(BUILD_LIB),y)
$(LIB_PRANA):
	@make -C $(LIB_PRANA_ROOT) $(MST9U_FPGA_FLAG) $(VERIFY_GE_FLAG)
	@make -C $(LIB_PRANA_ROOT) $(MST9U_FPGA_FLAG) export_lib \
	PRANA_LIB_PATH=$(LIB_PRANA_PATH_F) PRANA_INC_PATH=$(LIB_PRANA_INC_F);
#	@cp -f $(LIB_PRANA_ROOT)/$(LIB_PRANA) $(ROOT)/core/lib/MST9U

$(LIB_MXLIB) :
	@make -C $(LIB_MXLIB_ROOT) $(MST9U_FPGA_FLAG)
	@make -C $(LIB_MXLIB_ROOT) $(MST9U_FPGA_FLAG) export_lib \
	BSP_LIB_PATH=$(DRV_BSP_LIB_F) BSP_INC_PATH=$(DRV_BSP_INC_F);
endif


ifeq ($(OS_TYPE),linux)
merge: $(RES_BIN)
else
ifeq ($(OS_TYPE),nos_mips)
merge: $(MERGE_BIN)
else
ifneq ($(BUILD_TARGET),MAIN_AP_SYSTEM)
merge: $(MERGE_ELF) $(MERGE_BIN)
else
merge: $(MERGE_BIN)
endif
endif
endif

ifeq ($(OS_TYPE),nos_mips)
dis: $(AP_DIS)
else
dis: $(AP_DIS) $(MERGE_DIS)
endif

HEAP_START=$$(cat HEAP_START.txt)
HEAP_END=$$(cat HEAP_END.txt)
HEAP_SIZE=$$((($(HEAP_END)-$(HEAP_START))/1024))
HEAP_START_STRING=              ___heap = .
HEAP_END_STRING=                ___heap_end = (RAM_START + RAM_SIZE)

DATA_START     = $(shell $(AWK) '$$2 == "__ram_data_start" { print $$1 }' $(BINPATH)/AP.map)
DATA_END       = $(shell $(AWK) '$$2 == "__ram_data_end" { print $$1 }' $(BINPATH)/AP.map)
UNCOMPRESS_END = $(shell $(AWK) '$$2 == "__uncompress_end" { print $$1 }' $(BINPATH)/AP.map)
DATA_SIZE=$$(($(DATA_END)-$(DATA_START)))

ifeq ($(CHIP_FAMILY),MST9U)
UNCOMP_LEN=$$(($(UNCOMPRESS_END)))
else
UNCOMP_LEN=14336
endif

#ram_start  = $(shell $(AWK) '$$2 == "__ram_data_start" { print $$1 }' $(BINPATH)/AP.map)
ram_start  = $(shell grep '__ram_data_start =' $(BINPATH)/AP.map | sed 's/^.*0x\([0-9,a-f]*\).*/0x\1/')

test:
	grep '__ram_data_start =' $(BINPATH)/AP.map | sed 's/^.*0x\([0-9,a-f]*\).*/0x\1/'>DATA_START.txt
	grep '__ram_data_end =' $(BINPATH)/AP.map | sed 's/^.*0x\([0-9,a-f]*\).*/0x\1/'>DATA_END.txt
	grep '__UNCOMPRESS_END =' $(BINPATH)/AP.map | sed 's/^.*0x\([0-9,a-f]*\).*/0x\1/'>UNCOMPRESS_END.txt
	@echo "DATA_START= $(DATA_START)"
	@echo "DATA_END  = $(DATA_END)"
	@echo "DATA_SIZE = $(DATA_SIZE)"
	@echo "UNCOMPRESS_END = $(UNCOMPRESS_END)"
	@echo "RAM_SART=$(ram_start)"
	@echo "UNCOMP_LEN=$(UNCOMP_LEN)"

sboot: $(AP_BIN)
	@grep '__heap =' $(BINPATH)/AP.map | sed 's\$(HEAP_START_STRING)\\g' | sed 's/^.*0x/0x/g'>HEAP_START.txt;
	@grep '__heap_end =' $(BINPATH)/AP.map | sed 's\$(HEAP_END_STRING)\\g' | sed 's/^.*0x/0x/g'>HEAP_END.txt;
	@echo "HEAP_START= $(HEAP_START)"
	@echo "HEAP_END  = $(HEAP_END)"
	@echo "$(HEAP_SIZE)">HEAP_SIZE.txt
#	@rm HEAP_START.txt
#	@rm HEAP_END.txt
#	@echo "HEAP_SIZE = $(HEAP_SIZE)KB"
	@awk '{if($$1>=100) {print "HEAP_SIZE = "$$1" KB";rm "HEAP_SIZE.txt";}else {print "Error:HEAP_SIZE("$$1"KB) is less than 100 KB";exit 1}}' HEAP_SIZE.txt
	@echo "[SBOOT] $@"
    ifeq ($(BIN_FORMAT),COMPRESS)
#		@$(shell $(LZSSDIR)/lzss.out C $(UNCOMP_LEN) $(BINPATH)/$(AP_NAME).bin $(BINPATH)/$(AP_COMPRESS_NAME).bin;)
        ifeq ($(UNAME), Linux)
			$(shell $(MSCOMPDIR)/mscompress -c -u $(UNCOMP_LEN) -9 $(BINPATH)/$(AP_NAME).bin > $(BINPATH)/$(AP_COMPRESS_NAME).bin;)
        else
			@$(shell $(MSCOMPDIR)/mscompress.exe -c -u $(UNCOMP_LEN) -9 $(BINPATH)/$(AP_NAME).bin > $(BINPATH)/$(AP_COMPRESS_NAME).bin;)
        endif
		@$(shell cp $(BINPATH)/$(AP_COMPRESS_NAME).bin $(ROOT)/boot/sboot/bin/$(AP_NAME).bin; cp $(BINPATH)/$(AP_NAME).map $(ROOT)/boot/sboot/bin;)
    else
        ifeq ($(BIN_FORMAT),COMPRESS7)
		@$(shell $(MSCOMPDIR)/mscompress7 e $(UNCOMP_LEN) $(BINPATH)/$(AP_NAME).bin $(BINPATH)/$(AP_COMPRESS_NAME).bin;)
		@$(shell cp $(BINPATH)/$(AP_COMPRESS_NAME).bin $(ROOT)/boot/sboot/bin/$(AP_NAME).bin; cp $(BINPATH)/$(AP_NAME).map $(ROOT)/boot/sboot/bin;)
        else
		@$(shell cp $(BINPATH)/$(AP_NAME).bin $(ROOT)/boot/sboot/bin; cp $(BINPATH)/$(AP_NAME).map $(ROOT)/boot/sboot/bin;)
        endif
    endif
	@(cd $(ROOT)/boot/sboot; $(MAKE) clean;)
	@( rm -rf $(ROOT)/boot/sboot/out;)
	@( mkdir -p $(ROOT)/boot/sboot/out;)

    ifeq ($(MEM_TYPE),DDR3_1866)
        ifeq ($(DEBUG_FUN_SEL),DEBUG_FUN_ENABLE)
		@(cp $(ROOT)/boot/sboot/bin/$(HP_MODEL_NAME)/$(BOARD_TYPE_SEL)/sboot_1866.bin $(ROOT)/boot/sboot/out/sboot.bin;)
        else
		@(cp $(ROOT)/boot/sboot/bin/$(HP_MODEL_NAME)/$(BOARD_TYPE_SEL)/sboot_1866_msgoff.bin $(ROOT)/boot/sboot/out/sboot.bin;)
        endif
    endif    
    ifeq ($(MEM_TYPE),DDR3_2133)
        ifeq ($(DEBUG_FUN_SEL),DEBUG_FUN_ENABLE)
		@(cp $(ROOT)/boot/sboot/bin/$(HP_MODEL_NAME)/$(BOARD_TYPE_SEL)/sboot.bin $(ROOT)/boot/sboot/out/sboot.bin;)
        else
		@(cp $(ROOT)/boot/sboot/bin/$(HP_MODEL_NAME)/$(BOARD_TYPE_SEL)/sboot_msgoff.bin $(ROOT)/boot/sboot/out/sboot.bin;)
        endif
    endif    
    ifeq ($(MEM_TYPE),DDR2_1333)
        ifeq ($(DEBUG_FUN_SEL),DEBUG_FUN_ENABLE)
		@(cp $(ROOT)/boot/sboot/bin/$(HP_MODEL_NAME)/$(BOARD_TYPE_SEL)/sboot_1333.bin $(ROOT)/boot/sboot/out/sboot.bin;)
        else
		@(cp $(ROOT)/boot/sboot/bin/$(HP_MODEL_NAME)/$(BOARD_TYPE_SEL)/sboot_1333_msgoff.bin $(ROOT)/boot/sboot/out/sboot.bin;)
        endif
    endif  
 
	@if [ ! -d $(ROOT)/boot/sboot/bin/DaisyChain ]; then \
	mkdir $(ROOT)/boot/sboot/bin/DaisyChain ; fi

	@if [ -e $(DPOUT_BIN) ]; then \
	(cp -f $(DPOUT_BIN)  $(ROOT)/boot/sboot/bin/DaisyChain/ ); \
	else \
	(cp -f $(ROOT)/core/bin/daisy_chain/daisy_chain.bin  $(ROOT)/boot/sboot/bin/DaisyChain/ ); fi  
########################################################################################
#   since we can use SW PM, then PM.bin should be compiled according to BOARD define
########################################################################################
	@(/bin/cp -f $(PM_BIN) $(ROOT)/boot/sboot/out;)
########################################################################################
    ifeq ($(BUILD_TARGET),MAIN_AP_SYSTEM)
	$(MAKE) -C $(ROOT)/boot/sboot _FLASH_CHUNK_BASE_ADDRESS=$(BL_SIZE)
    else
	@$(MAKE) -C $(ROOT)/boot/sboot
    endif
    SBOOT_BIN_SIZE = $(shell stat -c %s $(ROOT)/boot/sboot/out/sboot.bin)

ifeq ($(OS_TYPE),nos_mips)
$(AP_ELF) : $(OBJ_S) $(OBJ_C) $(OBJ_B) $(PRANA_LIB) $(MONITOR_LIB)
	@echo "[LD]  $@"
	@echo "[LD]  $(LD_LIB)"
	@$(CC) $(LD_OPTS) -o $(AP_ELF) $(OBJ_C) -Wl,--start-group $(BSP_LIB) $(MONITOR_LIB) $(PRANA_LIB) -Wl,--end-group $(LD_LIB)
else

ifeq ($(OS_TYPE),linux)
$(AP_ELF) : $(OBJ_S) $(OBJ_C) $(OBJ_B)
	@echo "[LD]  $@"
	@$(CC) -EL -msoft-float -Wl,--gc-sections $(WARN_FLAG) -o $@ -Wall -Wl,--start-group -Wl,--whole-archive $^ $(MONITOR_LIB) -Wl,--no-whole-archive $(LDLIB) -Wl,--end-group
else
ifeq ($(BUILD_APLIB), y)
$(AP_ELF) : $(OBJ_S) $(OBJ_C) $(OBJ_B) $(MONITOR_LIB)
	@echo "[LD]  $@"
	@$(CC) $(LD_OPTS) -Wl,-Map,$(AP_MAP) -Wl,--start-group $^ -Wl,--end-group -T$(LOADER) -o $@ $(LDLIB)
	@$(OBJDUMP) $@ -S > $(AP_DIS)
else
$(AP_ELF) : $(OBJ_S) $(OBJ_C) $(OBJ_B) $(MONITOR_LIB)
	@echo "[LD]  $@"
ifeq ($(PROJ), R2_MST9U3_HP)
	@cp -f $(MONITOR_LIB_EREAD)_MST9U3 $(MONITOR_LIB_EREAD)
else
	@cp -f $(MONITOR_LIB_EREAD)_MST9U2 $(MONITOR_LIB_EREAD)
endif 
	
	@$(CC) $(LD_OPTS) -Wl,-Map,$(AP_MAP) -Wl,--start-group $^ $(MONITOR_AP_LIB) -Wl,--end-group -T$(LOADER) -o $@ $(LDLIB)
	@$(OBJDUMP) $@ -S > $(AP_DIS)
endif
endif

endif
	@$(SIZE) $@


ifeq ($(CHIP_FAMILY),MST9U)
$(AP_BIN) : $(AP_ELF)
	@echo "[BIN] $@"
	@$(OBJCOPY) -O binary -S -g -x -X -R .sbss -R .bss -R .reginfo $< $@
endif


ifeq ($(AEON_TYPE),aeonR2)
$(AP_OBJ): $(AP_BIN)
    ifeq ($(BIN_FORMAT),COMPRESS)
#		$(shell $(LZSSDIR)/lzss.out C $(UNCOMP_LEN) $(BINPATH)/AP.bin $(BINPATH)/AP_C.bin; cd $(BINPATH); $(OBJCOPY) -I binary -O elf32-littleaeon -B aeon:aeonR2 --prefix-sections=bin AP_C.bin ../$(OBJPATH)/AP.o)
		$(shell $(MSCOMPDIR)/mscompress -c -u $(UNCOMP_LEN) -9 $(BINPATH)/$(AP_NAME).bin > $(BINPATH)/$(AP_COMPRESS_NAME).bin; cd $(BINPATH); $(OBJCOPY) -I binary -O elf32-littleaeon -B aeon:aeonR2 --prefix-sections=bin AP_C.bin ../$(OBJPATH)/AP.o)
    else
		$(shell cd $(BINPATH); $(OBJCOPY) -I binary -O elf32-littleaeon -B aeon:aeonR2 --prefix-sections=bin AP.bin ../$(OBJPATH)/AP.o)
    endif
else
$(AP_OBJ): $(AP_BIN)
    ifeq ($(BIN_FORMAT),COMPRESS)
		$(shell $(LZSSDIR)/lzss.out C $(UNCOMP_LEN) $(BINPATH)/AP.bin $(BINPATH)/AP_C.bin; cd $(BINPATH); $(OBJCOPY) -I binary -O elf32-littleaeon -B aeon --prefix-sections=bin AP_C.bin ../$(OBJPATH)/AP.o)
    else
		$(shell cd $(BINPATH); $(OBJCOPY) -I binary -O elf32-littleaeon -B aeon --prefix-sections=bin AP.bin ../$(OBJPATH)/AP.o)
endif
endif

ifeq ($(OS_TYPE),nos_aeon)
$(MERGE_BIN) : $(AP_BIN)
	@echo "[BIN] $@"
	$(shell cp $(ROOT)/boot/sboot/out/all.bin $(MERGE_BIN);)
    ifeq ($(BIN_FORMAT),COMPRESS)
        ifeq ($(BUILD_TARGET),BLOADER_SYSTEM)
			$(BinIDPackFiles) -BIGENDIAN -CRC16ENABLE -multiflash 8 65536 0958336900 $@ $(BIN_INFO) $(IMGINFO_OFFSET) $(APC_BIN) 0 $(OS_TYPE)
        else
            ifeq ($(BUILD_TARGET),MAIN_AP_SYSTEM)
				@cat $(BINPATH)_BLOADER/MERGE.bin $(ROOT)/boot/sboot/out/chunk_header.bin $(APC_BIN) > $@
				@ls -lh $(BINPATH)_BLOADER/MERGE.bin $(BINPATH)/$(AP_COMPRESS_NAME).bin $(MERGE_BIN)
            endif
			$(BinIDPackFiles) -BIGENDIAN -CRC16ENABLE -multiflash 8 8 0958336900 $@ $(BIN_INFO) $(IMGINFO_OFFSET) $(APC_BIN) 0 $(OS_TYPE) $(PM_BIN_SIZE) $(SBOOT_BIN_SIZE) $(UNCOMP_LEN)
        endif
    else
        ifeq ($(BIN_FORMAT),COMPRESS7)
            ifeq ($(BUILD_TARGET),BLOADER_SYSTEM)
				$(BinIDPackFiles) -BIGENDIAN -CRC16ENABLE -multiflash 8 65536 0958336900 $@ $(BIN_INFO) $(IMGINFO_OFFSET) $(APC_BIN) 1 $(OS_TYPE) $(PM_BIN_SIZE) $(SBOOT_BIN_SIZE) $(UNCOMP_LEN)
            else
				ifeq ($(BUILD_TARGET),MAIN_AP_SYSTEM)
					@cat $(BINPATH)_BLOADER/MERGE.bin $(ROOT)/boot/sboot/out/chunk_header.bin $(APC_BIN) > $@
					@ls -lh $(BINPATH)_BLOADER/MERGE.bin $(BINPATH)/$(AP_COMPRESS_NAME).bin $(MERGE_BIN)
				endif
				$(BinIDPackFiles) -BIGENDIAN -CRC16ENABLE -multiflash 8 8 0958336900 $@ $(BIN_INFO) $(IMGINFO_OFFSET) $(APC_BIN) 1 $(OS_TYPE) $(PM_BIN_SIZE) $(SBOOT_BIN_SIZE) $(UNCOMP_LEN)
            endif
        else
            ifeq ($(BUILD_TARGET),BLOADER_SYSTEM)
				$(BinIDPackFiles) -BIGENDIAN -CRC16ENABLE -multiflash 8 65536 0958336900 $@ $(BIN_INFO) $(IMGINFO_OFFSET) $(AP_BIN)
            else
                ifeq ($(BUILD_TARGET),MAIN_AP_SYSTEM)
					@cat $(BINPATH)_BLOADER/MERGE.bin $(ROOT)/boot/sboot/out/chunk_header.bin $(AP_BIN) > $@
					@ls -lh $(BINPATH)_BLOADER/MERGE.bin $(AP_BIN) $(MERGE_BIN)
                endif
				$(BinIDPackFiles) -BIGENDIAN -CRC16ENABLE -multiflash 8 8 0958336900 $@ $(BIN_INFO) $(IMGINFO_OFFSET) $(AP_BIN) $(OS_TYPE)
            endif
        endif
    endif

    ifeq ($(GEN_BIN_SIZE), FULL)
	@$(FillBin) $(MERGE_BIN) $(FULL_BIN) $(BIN_FULLSIZE)
    endif
      
    ifeq ($(MERGE_EDID2BIN), YES)

ifeq ($(HP_MODEL_NAME),HP_Envy27)
	@$(MergeEDID2Bin) $(MERGE_BIN) $(TRIM_SIZE) $(MERGE_EDID_BIN) $(DP_EDIDBin) $(DP2_EDIDBin) $(MHL1_EDIDBin) \
	$(MHL2_EDIDBin) $(HDCPKEY22Bin) $(BLANK4KBin) 
else      
	@$(MergeEDID2Bin) $(MERGE_BIN) $(TRIM_SIZE) $(MERGE_EDID_BIN) $(DP_EDIDBin) $(BLANK4KBin) $(MHL1_EDIDBin) \
	$(MHL2_EDIDBin) $(HDCPKEY22Bin) $(BLANK4KBin)       
endif      
    endif
endif

$(RES_BIN) : $(AP_ELF)
	@echo "[BIN] $@"
	$(BinIDPackResources) -BIGENDIAN -CRC16ENABLE 8 8 0958336900 $< $@ $(BIN_INFO)
#	@cp core/bin/s7/audio/out_dvb_t3_d.bin $(BINPATH)/au_d.bin
#	@cp core/bin/s7/audio/out_dvb_t3_s.bin $(BINPATH)/au_s.bin
	@./generate_pnl_bin.sh $(BINPATH)/AP.elf $(BINPATH)


$(OBJ_B) $(BL_OBJ_B): $(OBJPATH)/%.o : %.bin
	@echo "[BIN] $@"
	@$(shell cd $(dir $<); $(OBJCOPY) -I binary -O elf32-littleaeon -B aeon --prefix-sections=bin $(notdir $<) $(abspath $@))

$(OBJPATH)/%.o: %.S
	$(call make-depend-compile,$<,$@,$(subst .o,.d,$@))

$(OBJPATH)/%.o: %.c
	$(call make-depend-compile,$<,$@,$(subst .o,.d,$@))

$(OBJPATH)/%.o: %.bin
	@echo "[BIN] $@"
	@$(shell cd $(dir $<); $(OBJCOPY) -I binary -O elf32-littleaeon -B aeon --prefix-sections=bin $(notdir $<) $(abspath $@))

.c.ln:  ;   lint -abhi $*.c
.elf.dis: ; @echo "[DIS] $@" ; $(OBJDUMP) -d -h -S $< > $@
.elf.sym: ; @echo "[SYM] $@" ; $(NM) -a -S $< > $@
.elf.siz: ; @echo "[SIZ] $@" ; $(SIZE) $< > $


LINT_INC=$(subst -I,,$(INC_DIR))
LINT_SRC_C=$(SRC_C)
LINT_DEF=$(subst -D,-d,$(filter -D%,$(CC_OPTS)))

lint:
ifneq ($(DISABLE_LINT),1)
	@(\
	echo "scripts/co-gnu3.lnt"; \
	echo $(LINT_OPT1); \
	echo | $(CPP) -dM | \
	sed -e '/LONG_LONG/d' | \
	sed -e 's/#define \([^ ]*\) "\(..*\)"/-d"\1=(\2)"/' | \
	sed -e 's/#define \([^ ]*\) \(..*\)/-d"\1=\2"/' | \
	sed -e 's/#define /-d/'; \
	for i in $(LINT_DEF); do \
		echo $$i; \
	done; \
	for i in $(LINT_INC); do \
		echo -i\"$$i\"; \
	done; \
	for i in `$(REALPATH) \`echo | $(CPP) -x c -Wp,-v 2>&1 | grep '^ '\``; do \
		echo -i\"$$i\"; \
	done; \
	for i in $(LINT_SRC_C); do \
		echo $$i; \
	done; \
	) > $(BINPATH)/$(PROJ).lnt
	@$(FLINT) -fff $(BINPATH)/$(PROJ).lnt > $(BINPATH)/LINT.txt; \
	 grep -v 'Module:' $(BINPATH)/LINT.txt | grep -v '^$$' ; true
	@echo
	@echo `grep 'Error' $(BINPATH)/LINT.txt | wc -l` LINT Errors
endif


ifeq ($(OS_TYPE),nos_aeon)
loader:
ifeq ($(BUILD_TARGET),MAIN_AP_SYSTEM)
	@$(MAKE) PROJ=$(PROJ)_BLOADER
endif
endif
ifeq ($(OS_TYPE),nos_mips)
loader:
ifeq ($(BUILD_TARGET),MAIN_AP_SYSTEM)
	@$(MAKE) PROJ=$(PROJ)_BLOADER
endif
endif
# Project Setup
ifeq ($(OS_TYPE),nos_aeon)
setup:
	@mkdir -p $(OBJDIR) $(BINDIR);
	@rm -f $(call src-to-obj,$(REBUILD_FILES))
	@$(CC) -E -P -xc $(CC_MTOPTS) $(LDSCRIPT_SRC) > $(LOADER); chmod 744 $(LOADER)
	@$(AWK) '{if ($$2=="BEON_MEM_ADR") print $$3;}' $(MMAP) > $(ROOT)/project/mmap/aeon_mem_adr
	@$(AWK) 'BEGIN { \
	            getline < "$(ROOT)/project/mmap/aeon_mem_adr"; \
	            ADR = $$1 \
	        } \
	        { \
	            if ($$1=="RAM_START") gsub($$3, ""ADR";", $$0); \
	            if ($$1=="ram" && $$3=="ORIGIN") gsub($$5, ""ADR",", $$0); \
	            if ($$1==".prog_img_info") gsub($$2, "("ADR"+0x1100)", $$0); \
	            if ($$1==".img_info") gsub($$2, "("ADR"+0x2000)", $$0); \
	            print > FILENAME ".tmp"; \
	        }' $(LOADER)
	        @mv -f $(LOADER).tmp $(LOADER)
	@$(AWK) '{if ($$2=="BEON_MEM_LEN") print $$3;}' $(MMAP) > $(ROOT)/project/mmap/aeon_mem_len
	@$(AWK) 'BEGIN { \
	            getline < "$(ROOT)/project/mmap/aeon_mem_len"; \
	            LEN = $$1\
	        } \
	        { \
	            if ($$1=="RAM_SIZE") gsub($$3, ""LEN";", $$0); \
	            if ($$1=="ram" && $$6=="LENGTH") gsub($$8, ""LEN"", $$0); \
	            print > FILENAME ".tmp"; \
	        }' $(LOADER)
	        @mv -f $(LOADER).tmp $(LOADER)
	@$(shell touch $(SYS_INIT_FILES))
	@echo "----  < MODEL NAME : $(HP_MODEL_NAME) >"
	@echo "----  < PANEL TYPE : $(PANEL_TYPE) >"
	@echo "----  < BOARD_TYPE : $(BOARD_TYPE_SEL) >"
	@echo "----  < DEBUG_FUNC : $(DEBUG_FUN_SEL) >"
else
setup:
	@mkdir -p $(OBJDIR) $(BINDIR);
	@rm -f $(call src-to-obj,$(REBUILD_FILES))
	@$(AWK) '{if ($$1==".prog_img_info") print "#define IMG_INFO_OFFSET " $$2"+0x10000"}' \
			$(ROOT)/project/loader/target.ld > $(ROOT)/core/middleware/usbupgrade/include/mw_imginfo.h
endif
env:
	@echo CC_OPTS = $(CC_OPTS)
	@echo LD_OPTS = $(LD_OPTS)
	@echo SRC = $(SRC)

# Project API
DOCGEN :
#	doxygen.exe $(ROOT)/project/Doxygen/Venus_3RD_PARTY_DDI_API.doxygen

# Project Clean
clean :
	@if [ -d $(OBJPATH) ] ; then \
	find $(OBJPATH) -name '*.o' -exec rm -f {} \;;\
	fi;
	rm -f $(BINPATH)/$(AP_NAME).* $(BINPATH)/$(MERGE_NAME).* ###$(BINPATH)/$(AP_NAME)_2.* $(BINPATH)/$(MERGE_NAME)_2.*
        ifeq ($(BUILD_TARGET),MAIN_AP_SYSTEM)
		@$(MAKE) PROJ=$(PROJ)_BLOADER clean
        endif
ifeq ($(BUILD_LIB),y)
	@echo "clean prana2 lib..."
	@make -C $(LIB_PRANA_ROOT) clean > /dev/null;
	@echo "clean mxlib..."
	@make -C $(LIB_MXLIB_ROOT) clean > /dev/null;
	@echo "done!"
endif

realclean:
	rm -rf Bin_* Obj_*

checkstack: $(AP_ELF)
ifeq ($(CROSSCOMPILE), aeon-)
	$(OBJDUMP) -d $(AP_ELF) | scripts/checkstack.pl aeon
else
	$(OBJDUMP) -d $(AP_ELF) | scripts/checkstack.pl mips
endif

# Project Dependence

# $(call make-depend-compile,source-file,object-file,depend-file)
define make-depend-compile
	@echo "[CC]  $1"
	@mkdir -p $(dir $2)
	@$(CC) -MM -MF $3 -MP -MT $2 $(CC_OPTS) $1
	@$(CC) $(CC_OPTS) -o $2 -c $1
endef

src-to-obj = $(patsubst %.bin,$(OBJPATH)%.o,\
             $(patsubst %.S,$(OBJPATH)/%.o,\
             $(patsubst %.c,$(OBJPATH)/%.o,$1)))

-include $(OBJ_S:.o=.d) $(OBJ_C:.o=.d)