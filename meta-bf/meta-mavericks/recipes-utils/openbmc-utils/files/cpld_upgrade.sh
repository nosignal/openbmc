#!/bin/sh
#
# Copyright 2014-present Facebook. All Rights Reserved.
#
# This program file is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program in a file named COPYING; if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301 USA
. /usr/local/bin/openbmc-utils.sh

PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin

board_subtype=$(wedge_board_subtype)
board_rev=$(wedge_board_rev)

usage() {
    echo "Usage: ${0} <target board (upper lower)> <target cpld (sys fan)> <cpld_image>" >&2
}

upgrade_upper_syscpld() {
    echo "Started Upper SYSCPLD upgrade .."
    # Select BMC channel
    echo out > /tmp/gpionames/CPLD_UPPER_JTAG_SEL/direction
    echo 1 > /tmp/gpionames/CPLD_UPPER_JTAG_SEL/value
    #disable heartbeat
    i2cset -y -f 12 0x30 0x2e 0x18

    #program syscpld, board_rev=010 new board, board_rev=001 old board
    if [ $board_rev -eq 10 ]; then
	    ispvm syscpld uppersys $1
		rc=$?
	elif [ $board_rev -eq 1 ]; then
        jbi -r -aPROGRAM -gc57 -gi56 -go58 -gs147 $1 | grep -i "Success"
		rc=$?
	else
	    echo "Fail: board rev not correct"
		exit 1
	fi

    if [ $rc != "0" ]; then
        echo "Finished Upper SYSCPLD upgrade: Pass"
    else
        echo "Finished Upper SYSCPLD upgrade: Fail (Program failed)"
    fi
}

upgrade_lower_syscpld() {
    echo "Started Lower SYSCPLD upgrade .."
    # Select BMC channel
    echo out > /tmp/gpionames/CPLD_JTAG_SEL/direction
    echo 1 > /tmp/gpionames/CPLD_JTAG_SEL/value
    #disable heartbeat
    i2cset -y -f 12 0x31 0x2e 0x18

    #program syscpld, board_rev=010 new board, board_rev=001 old board
    if [ $board_rev -eq 10 ]; then
	    ispvm syscpld lowersys $1
		rc=$?
	elif [ $board_rev -eq 1 ]; then
        jbi -r -aPROGRAM -gc102 -gi101 -go103 -gs100 $1 | grep -i "Success"
		rc=$?
	else
	    echo "Fail: board rev not correct"
		exit 1
	fi

    if [ $rc != "0" ]; then
        echo "Finished Lower SYSCPLD upgrade: Pass"
    else
        echo "Finished Lower SYSCPLD upgrade: Fail (Program failed)"
    fi
}

upgrade_upper_fancpld() {
    echo "Started Upper FANCPLD upgrade .."
    # Enable CPLD update (UPD)
    echo out > /tmp/gpionames/UPPER_FANCARD_CPLD_UPD_EN/direction
    echo 0 > /tmp/gpionames/UPPER_FANCARD_CPLD_UPD_EN/value
    # Select upper channel
    echo out > /tmp/gpionames/BMC_FANCARD_CPLD_JTAG__SEL/direction
    echo 1 > /tmp/gpionames/BMC_FANCARD_CPLD_JTAG__SEL/value

    #program syscpld, board_rev=010 new board, board_rev=001 old board
    if [ $board_rev -eq 10 ]; then
	    ispvm syscpld fan $1
		rc=$?
	elif [ $board_rev -eq 1 ]; then
        jbi -aPROGRAM -gc77 -gi78 -go79 -gs76 $1 | grep -i "Success"
		rc=$?
	else
	    echo "Fail: board rev not correct"
		exit 1
	fi
    
    if [ $rc != "0" ]; then
        echo "Finished Upper FANCPLD upgrade: Pass"
    else
        echo "Finished Upper FANCPLD upgrade: Fail (Program failed)"
    fi
}

upgrade_lower_fancpld() {
    echo "Started Lower FANCPLD upgrade .."

    if [ "$board_subtype" == "Montara" ] || [ "$board_subtype" == "Mavericks" ] ; then
        # Enable CPLD update (UPD)
        echo out > /tmp/gpionames/CPLD_UPD_EN/direction
        echo 0 > /tmp/gpionames/CPLD_UPD_EN/value
    fi

    if [ "$board_subtype" == "Mavericks" ] ; then
        # Select lower channel
        echo out > /tmp/gpionames/BMC_FANCARD_CPLD_JTAG__SEL/direction
        echo 0 > /tmp/gpionames/BMC_FANCARD_CPLD_JTAG__SEL/value
    fi

    #program syscpld, board_rev=010 new board, board_rev=001 old board
    if [ $board_rev -eq 10 ]; then
	    ispvm syscpld fan $1
		rc=$?
	elif [ $board_rev -eq 1 ]; then
        jbi -aPROGRAM -gc77 -gi78 -go79 -gs76 $1 | grep -i "Success"
		rc=$?
	else
	    echo "Fail: board rev not correct"
		exit 1
	fi
    
    if [ $rc != "0" ]; then
        echo "Finished Lower FANCPLD upgrade: Pass"
    else
        echo "Finished Lower FANCPLD upgrade: Fail (Program failed)"
    fi
}

# Check the number of arguments provided
if [ $# -ne 3 ]; then
    usage
    exit 1
fi

if [ $1 != "upper" ] && [ $1 != "lower" ]; then
    usage
    exit 1
fi
if [ $2 != "sys" ] && [ $2 != "fan" ]; then
    usage
    exit 1
fi

# Check the file path provided is a valid one.
cpldfile="$3"
if [ ! -f $cpldfile ]; then
    echo "$cpldfile does not exist"
    exit 1
fi

# Check the file path extension is .jbc or .vme
filename="$(basename $cpldfile)"

if [ $board_rev -eq 10 ]; then
	if [ ${filename: -4} != ".vme" ]; then
		echo "Must pass in a .vme file"
		exit 1
	fi
elif [ $board_rev -eq 1 ]; then
	if [ ${filename: -4} != ".jbc" ] && [ ${filename: -4} != ".JBC" ]; then
		echo "Must pass in a .jbc file"
		exit 1
	fi
else
	echo "Fail: board rev not correct"
	exit 1
fi

# 2U: Mavericks, 1U: Montara, Newport
if [ $1 == "upper" ] && [ "$board_subtype" != "Mavericks" ]; then
    echo "upper board does not exist"
	echo $board_subtype
    exit 1
fi

# Check the file name and upgrade accordingly
if [ $1 == "upper" ]; then
    if [ $2 == "sys" ]; then
        upgrade_upper_syscpld $cpldfile
    else
        upgrade_upper_fancpld $cpldfile
    fi
elif [ $1 == "lower" ]; then
    if [ $2 == "sys" ]; then
        upgrade_lower_syscpld $cpldfile
    else
        upgrade_lower_fancpld $cpldfile
    fi
else
  usage
  exit 1
fi
