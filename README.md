This is a quickly thrown together script that I needed to work around the fact
that the ip[6]tables found in the Maemo 5 community repos for Nokia N900 phones
seem to be prone to race conditions. I found that two processes running
`iptables-restore` would just get in each others' ways, with only one
succeeding and the other failing to commit its changes with a misleading error
message.

Worse, an `iptables-restore` running in parallel with an `iptables -I` command
was prone to adding a _**wrong**_ rule (something deep in the implementation must
have corrupted the rule data mid-write due to the other write, I guess).

As I understand it, iptables-restore is supposed to _not_ do this, but rather
the opposite: it's supposed to lock the netfilter tables until it can commit
the changes. Since that wasn't working, I wrapped xtables-multi (the command
which new-ish ip*tables-* are just symlinks to) with a script to manually use a
lockfile to ensure my iptables commands don't clobber each other, especially on
boot where they were really prone to doing so.

I'm putting this up, at the moment, in the hope that it's useful to someone.
It's not an ideal, polished product. It works, does the best it can to be
correct, and avoids creating a lockfile when it's not required. Maybe someone
besides me has issues with iptables comands racing against each other, and this
hopefully helps you too. Just bear in mind I coded this for my specific needs,
so this isn't a thoroughly architected for general use (see below about some
hardcoded pathnames used in this).

Also, if I were to ever reorganize my github stuff, this repo is more likely to
be renamed/combined-with-other-small-scripts-in-one-repo than e.g.
[esceval](https://github.com/mentalisttraceur/esceval) or
[poll](https://github.com/mentalisttraceur/poll).

In order to make it work with the minimum disruption of how "iptables" is
packaged in the Maemo 5 community repos, I just moved `/usr/sbin/xtables-multi`
to `/usr/sbin/xtables-multi.real`. That path is hardcoded, as is the assumption
that the script itself is named xtables-multi, (presumably) displacing the
original. If you need to adopt this for something else, e.g. Tomato USB router
firmware with `*tables-*` which don't symlink to `xtables-multi`, or just to use
different path, it should be trivial to adapt it manually. Also, all my N900s
have a ramdisk at `/run` (in line with modern Debian, like `/var/run` used to
be: I recommend adjusting your N900 so that both paths point to the same place,
but if that's unappealing to you, just tweak the "/run" part of the path).

Because iptables is an intrinsically Linux thing, I did not adhere to as
extreme of portability-zeal in this shell script as I typically do (another
example of this is my [fkdep](https://github/mentalisttraceur/fkdep) script,
where I forgo radical portability for just "stock N900" portability). And of
course, I used `flock(1)` for the locking mechanism, which isn't portable
outside of Linux, last I checked (at least in that you can't rely on it being
on base/stock install of a non-Linux OS, and as I understand it on some systems
`flock(2)` is implemented in terms of the process-associated, `fcntl(2)`-based,
record locking semantics).
