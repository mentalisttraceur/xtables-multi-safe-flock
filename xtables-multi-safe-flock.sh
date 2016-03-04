#!/bin/sh
# Copyright (C) 2016-03-04 Alexander Kozhevnikov <mentalisttraceur@gmail.com>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

# This is the heavily-commented version of this shell script. Written for you,
# valuable random person looking at my code (and because I had to put the ISC
# license text somewhere). I strip all comments and blank lines out of this for
# actual use/deployment on my phones.

# xtables-multi is one of those polymorphic binaries that behaves differently
# based on the name it's invoked as: if it's invoked as the name of a built in
# command, it behaves as that command. Otherwise, it seems to use the first
# first argument (I didn't look for documentation or the source code, just went
# off thorough observations of its behavior).
# 
# This script starts by mimicking this "which command am I running as" logic.
# This may seem redundant, but it serves two purposes:
# 1) We need to know the name of the command: otherwise we can't pick the right
# lockfile to use, or rule out commands like iptables-xml which don't need the
# lockfile.
# 2) There's no shell-only, _portable_ way to set the zeroth argument of a
# program. `exec -a` isn't portable to e.g. busybox ash builtin exec (it might
# be enable-able at compile-time for all I know, but not in the ones on my
# Maemo 5 and Tomato USB devices). So we have to determine the correct name,
# then invoke the actual xtables-multi binary with that as the first argument.

# basename "$0", but with in-shell variable substitutions:
arg0=${0##*/}

# Check the zeroth and first arguments for command name. First argument doesn't
# need the basename treatment: that's only for zeroth argument to compensate
# for the odds of pathname components ending up in it.
for name in "$arg0" "$1"
do
 case $name in
 
 # We have all IPv6 commands lock each other, and all IPv4 commands lock each
 # other. This is an assumption I'm making: that the two sets are distinct and
 # thus we don't need to lock IPv4 stuff when e.g. ip6tables-restore runs. But
 # I could be wrong, so please let me know if so. At this stage, it's just
 # determining the lockname - more checks before using it come later.
 ip6tables | ip6tables-restore | ip6tables-save | main6 | restore6 | save6)
  lockname=ip6tables
  break
 ;;
 iptables | iptables-restore | iptables-save | main4 | restore4 | save4)
  lockname=iptables
  break
 ;;
 
 # The xml command is just there to convert save output into xml output, it
 # makes no changes to the tables, so we can just execute it without locking.
 iptables-xml | xml)
  exec /usr/sbin/xtables-multi.real $arg0 "$@"
 esac
 
 # If it didn't match, we just blank arg0: the unquoted substitution will make
 # it "disappear" from the invocation. So we're "eliminating" arg0 from the
 # "argv" upon realizing it's not one of the valid command names. If the check
 # of argument 1 also fails, we'll loop here again with arg0 already blanked,
 # and then we can go directly to executing without locking: it'll just error,
 # giving the user an error message as it would if we weren't in the way.
 case $arg0 in
 '')
  exec /usr/sbin/xtables-multi.real "$@"
 esac
 arg0=
done

# Even for commands that could use locking, we know we don't need to lock when
# just printing help text, so if any of the arguments are the help option, we
# go directly to executing it without locking.
for arg
do
 case $arg in
 -h | --help)
  exec /usr/sbin/xtables-multi.real $arg0 "$@"
 esac
done

# Finally, a heuristic: root UID 0 can actually make changes, other UIDs won't
# get far enough before being denied for locking to be workwhile, plus if root
# makes the lockfile first, other users will not be able to open it for writing
# anyway.
case `id -u` in
0)
 # We open lockfile for writing and flock its file descriptor. Blocks until the
 # lock is acquired - if it fails, we'll abort out, instead of plowing on with
 # no lock.
 exec 3>/run/"$lockname".lock && flock 3 || exit $?
esac
# ..I'd actually like to extend this to a "capacities"-based check, instead of
# this blunt, imprecise, UID-based check. But there's no ubiquitous capacity
# checking command-line tool. Closest thing I could find is capsh, and it's not
# as ubiquitous as I'd like, nor obvious to me how to check if the invoker has
# a given capacity. Maybe I'll write some CLI tools for this using libcap-ng.
# But in any case, I'll try to make such checks "progressive enhancement", not
# a hard dependency.

# Finally, once the lock is acquired, we exec the actual command as normal.
# The lock will be released once all inherited copies of the locked file
# descriptor are closed: i.e. when the xtables command finished.
exec /usr/sbin/xtables-multi.real $arg0 "$@"
