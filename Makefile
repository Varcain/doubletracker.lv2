#
# Copyright (C) 2026 Kamil Lulko <kamil.lulko@gmail.com>
#
# This file is part of DoubleTracker.
#
# DoubleTracker is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# DoubleTracker is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with DoubleTracker. If not, see <https://www.gnu.org/licenses/>.
#

PREFIX ?= $(HOME)/.lv2
BUNDLE = doubletracker.lv2
DSP    = dsp/doubletracker.dsp

.PHONY: all clean install uninstall

all:
	faust2lv2 $(DSP)

clean:
	rm -rf $(BUNDLE)

install: all
	mkdir -p $(PREFIX)
	cp -r $(BUNDLE) $(PREFIX)/

uninstall:
	rm -rf $(PREFIX)/$(BUNDLE)
