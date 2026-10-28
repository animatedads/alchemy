# keyword instructions: the first part

this file has facts about some keyword instructions of oorexx, and about how to use do and loop.

```
ADDRESS
ADDRESS environment
ADDRESS environment expression
ADDRESS VALUE expression
ADDRESS environment expression WITH redirection
ADDRESS WITH redirection

redirection, each part one time at most:
  INPUT  NORMAL | STEM stem. | STREAM stream | USING expression
  OUTPUT NORMAL | STEM stem. [APPEND|REPLACE] | STREAM stream [APPEND|REPLACE] | USING expression [APPEND|REPLACE]
  ERROR  NORMAL | STEM stem. [APPEND|REPLACE] | STREAM stream [APPEND|REPLACE] | USING expression [APPEND|REPLACE]
```
address: an instruction that says what environment gets each command, and can send one command
this instruction can change the environment that gets each command, for all the next commands.
this instruction can also send one command to an environment, one time.
with an environment and an expression, the value of the expression goes as a command to that environment.
after that command, the environment is the same as before.
the environment is a literal or a constant symbol.
with only an environment, each next command goes to that environment, until the next address instruction.
this instruction keeps the name of the environment before the change.
with no environment, this instruction changes back to the environment before the last change.
so if you use this instruction with no environment two times, the environment changes from one to the other and back.
an empty string as the environment is the same as the default environment.
with the keyword value, the value of the expression is the name of the environment.
you can omit the keyword value when the expression starts with a special character, as an operator or one of the parentheses.
a trap can run when a command has an error.
a call to a routine does not change the two environment names: after the routine, they are the same as before the call.
the builtin function address gives the name of the environment now.
```
RC   .RS
```
after a command, the special variable and the environment symbol in the code before this get a value.
```
sh                            default on Unix-like systems
bsh bash csh ksh tcsh zsh     only on Unix-like systems
cmd                           default on Windows
command system ""             the same as the default
path                          on all systems
```
the code before this is a list of environment names.
each name in the list that is the name of a shell runs the command with that shell.
if the computer does not have the shell of an environment in the list, a command to that environment can not run, and an event is raised.
the environment names in line four of that list are the same as the default environment.
the environment path runs the command with no shell, so the command can not use the internal commands of a shell.
with the environment path, the variable path says where the computer can find the program of the command.
with the keyword with, you say where the command reads its input, and where it writes its output and its error output.
the input can come from a rexx object, and the output and the error output can go to a rexx object.
with no command, this change is for each next command; with a command, it is only for that command.
with no command, the change is a part of the name of the environment, and a call to a routine does not change it.
with no command, the objects and expressions after with do not run when this instruction runs.
then they run each time a command goes, with the variables at that time.
to give input, output, or error more than one time in one instruction is an error.
```
INPUT NORMAL
```
with this, the command reads its standard input.
```
INPUT STEM stem.
```
with this, the stem must be a stem variable.
the value of the stem with the tail 0 is the count of input lines.
the value of the stem with the tail one, two, and so on, is the first line, the second line, and so on.
```
INPUT STREAM stream
```
with this, the stream is a literal, a constant symbol, an environment symbol, or an expression in parentheses, that gives the name of a stream.
the command reads each line of that stream.
```
INPUT USING expression
```
with this, the expression is a literal, a constant symbol, an environment symbol, or an expression in parentheses.
if its value is a string, the command reads the string as one line.
if its value is a stem or a stream, the command reads it as with a stem or a stream.
if its value is an array, each item is a string and is one line; the command does not read an empty item.
its value can be any object that has a method to make an array, as a queue.
```
OUTPUT NORMAL
ERROR NORMAL
```
with this, the command writes to its default output or its default error output.
```
OUTPUT STEM stem. REPLACE
ERROR STEM stem. REPLACE
```
this is the default for a stem.
with this, the count of output lines goes in the stem with the tail 0, and each line goes in the stem with the tail of its number.
```
OUTPUT STEM stem. APPEND
ERROR STEM stem. APPEND
```
with this, the lines go in the stem after the lines that are in it, from the count in the tail 0 add 1.
then the value in the tail 0 is that count add the count of new lines.
```
OUTPUT STREAM stream REPLACE
OUTPUT STREAM stream APPEND
```
with a stream, the command writes each line to the stream.
with the first of the two, the default, the stream is empty before the command writes.
with the second of the two, the lines go at the end of the stream.
```
OUTPUT USING expression
ERROR USING expression
```
with this, the expression is a constant symbol, an environment symbol, or an expression in parentheses.
if its value is a stem or a file, the command writes to it as with a stem or a stream.
if its value is an output stream, the lines always go at its end, and you can not give the last keyword of the two code lines before this.
if its value is a queue, each line goes at the end of the queue, and you can not give that keyword.
if its value is a collection in order, the default makes the collection empty and then adds each line at its end.
with that keyword, the lines go at the end of the collection, and the collection keeps the items in it.
if the input and the output use the same object, the result is as you want.
if the output and the error output go to the same object, that object gets the lines of both.
the code:
```rexx
ADDRESS "CMD" 'dir "\Program Files"'            -- Windows
ADDRESS "sh" "ls /usr/bin"                      -- Unix-like system

address "" "cat" with input using "single line" -- Unix-like system: "single line"
address "" "ver" with output stem v.; say v.2   -- "Microsoft Windows ..."

address "" with input using (a) output using (a)
a = 4, 2, 3, 1
"sort"
say a~toString(, " ")                           -- 1 2 3 4

address CMD
"DIR C:\AUTOEXEC.BAT"
if rc=0 then "COPY C:\AUTOEXEC.BAT C:\*.TMP"
address EDIT

ADDRESS ("ENVIR"||number)  /* Same as ADDRESS VALUE "ENVIR"||number */
```
the result:
```
2to3-3.11
X11
Xvfb
[
aclocal
aclocal-1.16
activate-global-python-argcomplete
acyclic
add-apt-repository
addpart
addr2line
afm2pl
afm2tfm
age
age-keygen
aleph
ambiguous_words
amdgpu-arch-18
amstex
analyze-build-18
animate
animate-im6
animate-im6.q16
apt
apt-add-repository
apt-cache
apt-cdrom
apt-config
apt-get
apt-key
apt-mark
ar
arch
as
asan_symbolize
asan_symbolize-18
authorindex
autoconf
autoheader
autom4te
automake
automake-1.16
autoreconf
autoscan
autosp
autoupdate
awk
axohelp
b2sum
base32
base64
basename
basenc
bash
bashbug
bc
bcomps
bdftopcf
bdftruncate
bibtex
bibtex.original
bibtex8
bibtexu
bison
bison.yacc
browse
bugpoint
bugpoint-18
bunzip2
busctl
bzcat
bzcmp
bzdiff
bzegrep
bzexe
bzfgrep
bzgrep
bzip2
bzip2recover
bzless
bzmore
c++
c++filt
c-index-test-18
c89
c89-gcc
c99
c99-gcc
c_rehash
cachepic
callgrind_annotate
callgrind_control
captoinfo
cat
cc
ccomps
certutil
cg_annotate
cg_diff
cg_merge
chage
chattr
chcon
chfn
chgrp
chkdvifont
chktest
chmod
choom
chown
chrt
chsh
circo
cksum
clang
clang++
clang++-18
clang-18
clang-apply-replacements-18
clang-change-namespace-18
clang-check-18
clang-cl-18
clang-cpp-18
clang-doc-18
clang-extdef-mapping-18
clang-format
clang-format-18
clang-format-diff
clang-format-diff-18
clang-include-cleaner-18
clang-include-fixer-18
clang-linker-wrapper-18
clang-move-18
clang-offload-bundler-18
clang-offload-packager-18
clang-pseudo-18
clang-query-18
clang-refactor-18
clang-rename-18
clang-reorder-fields-18
clang-repl-18
clang-scan-deps-18
clang-tblgen-18
clang-tidy
clang-tidy-18
clang-tidy-diff
clang-tidy-diff-18.py
classifier_tester
clear
clear_console
cluster
clusterdb
cmake
cmp
cmsutil
cntraining
combine_lang_model
combine_tessdata
comm
compare
compare-im6
compare-im6.q16
composite
composite-im6
composite-im6.q16
conjure
conjure-im6
conjure-im6.q16
containerd
containerd-shim-runc-v2
convert
convert-im6
convert-im6.q16
corelist
cp
cpack
cpan
cpan5.38-x86_64-linux-gnu
cpp
cpp-13
createdb
createlang
createuser
crlutil
csplit
ctangle
ctest
ctie
ctr
ctwill
ctwill-refsort
ctwill-twinx
curl
cut
cvtsudoers
cweave
dash
date
dawg2wordlist
dbus-cleanup-sockets
dbus-daemon
dbus-monitor
dbus-run-session
dbus-send
dbus-update-activation-environment
dbus-uuidgen
dd
deb-systemd-helper
deb-systemd-invoke
debconf
debconf-apt-progress
debconf-communicate
debconf-copydb
debconf-escape
debconf-set-selections
debconf-show
delpart
derdump
detex
devnag
df
dh_autotools-dev_restoreconfig
dh_autotools-dev_updateconfig
dh_installtex
dh_installxmlcatalogs
diagtool-18
diff
diff3
diffimg
dijkstra
dir
dircolors
dirmngr
dirmngr-client
dirname
disdvi
display
display-im6
display-im6.q16
dmesg
dnsdomainname
docker
docker-proxy
dockerd
domainname
dot
dot2gxl
dot_builtins
dotty
dpkg
dpkg-architecture
dpkg-buildapi
dpkg-buildflags
dpkg-buildpackage
dpkg-buildtree
dpkg-checkbuilddeps
dpkg-deb
dpkg-distaddfile
dpkg-divert
dpkg-genbuildinfo
dpkg-genchanges
dpkg-gencontrol
dpkg-gensymbols
dpkg-maintscript-helper
dpkg-mergechangelogs
dpkg-name
dpkg-parsechangelog
dpkg-query
dpkg-realpath
dpkg-scanpackages
dpkg-scansources
dpkg-shlibdeps
dpkg-source
dpkg-split
dpkg-statoverride
dpkg-trigger
dpkg-vendor
dropdb
droplang
dropuser
dsymutil
dsymutil-18
dt2dv
du
dv2dt
dvi2tty
dvibook
dviconcat
dvicopy
dvihp
dvilj
dvilj2p
dvilj4
dvilj4l
dvilj6
dvilualatex
dvilualatex-dev
dviluatex
dvipdfm
dvipdfmx
dvipdft
dvipos
dvips
dviselect
dvispc
dvitodvi
dvitomp
dvitype
dwp
ebb
echo
edgepaint
editor
egrep
elfedit
enc2xs
encguess
env
epspdf
epspdftk
eptex
etex
euptex
ex
exceltex
expand
expiry
expr
extractbb
factor
faillog
fallocate
false
fc-cache
fc-cat
fc-conflist
fc-list
fc-match
fc-pattern
fc-query
fc-scan
fc-validate
fdp
ffmpeg
ffplay
ffprobe
fgrep
fig4latex
file
find
find-all-symbols-18
findmnt
fix-qdf
flock
fmt
fmtutil
fmtutil-sys
fmtutil-user
fold
fonttosfnt
free
funzip
fuser
fusermount
fusermount3
g++
g++-13
gapplication
gc
gcc
gcc-13
gcc-ar
gcc-ar-13
gcc-nm
gcc-nm-13
gcc-ranlib
gcc-ranlib-13
gcore
gcov
gcov-13
gcov-dump
gcov-dump-13
gcov-tool
gcov-tool-13
gdb
gdb-add-index
gdbtui
gdbus
gdbus-codegen
gencat
getconf
getent
getmapdl
getopt
gftodvi
gftopk
gftype
gi-compile-repository
gi-decompile-typelib
gi-inspect-typelib
gio
gio-querymodules
git
git-clang-format
git-clang-format-18
git-lfs
git-receive-pack
git-shell
git-upload-archive
git-upload-pack
glib-compile-resources
glib-compile-schemas
glib-genmarshal
glib-gettextize
glib-mkenums
gmake
gml2gv
gobject-query
gold
gp-archive
gp-collect-app
gp-display-html
gp-display-src
gp-display-text
gpasswd
gpg
gpg-agent
gpg-connect-agent
gpg2
gpgconf
gpgparsemail
gpgsm
gpgsplit
gpgtar
gpgv
gprof
gprofng
graphml2gv
gregorio
grep
gresource
groups
gsettings
gsftopk
gtester
gtester-report
gtk-update-icon-cache
gunzip
gv2gml
gv2gxl
gvcolor
gvgen
gvmap
gvmap.sh
gvpack
gvpr
gxl2dot
gxl2gv
gzexe
gzip
h2ph
h2xs
hardlink
head
helpztags
hishrink
histretch
hitex
hmaptool-18
hostid
hostname
hostnamectl
httpserv
hwasan_symbolize-18
i386
iconv
id
identify
identify-im6
identify-im6.q16
ifnames
import
import-im6
import-im6.q16
infocmp
infotocap
inimf
initex
install
instmodsh
intercept-build-18
ionice
ipcmk
ipcrm
ipcs
iptables-xml
ischroot
ispell-wrapper
jar
jarsigner
java
javac
javadoc
javap
jcmd
jconsole
jdb
jdeprscan
jdeps
jexec
jfr
jhsdb
jimage
jinfo
jlink
jmap
jmod
join
journalctl
jpackage
jps
jq
jrunscript
jshell
json_pp
jstack
jstat
jstatd
jwebserver
kbxutil
kernel-install
keytool
kill
killall
kpseaccess
kpsereadlink
kpsestat
kpsewhich
l3build
last
lastb
lastlog
latex
latex-dev
latex-wordcount
latexmk
lcf
ld
ld.bfd
ld.gold
ld.lld
ld.lld-18
ld.so
ld64.lld-18
ldd
lefty
less
lessecho
lessfile
lesskey
lesspipe
libnetcfg
libpng-config
libpng16-config
libreoffice
libtoolize
link
linux32
linux64
llc
llc-18
lld
lld-18
lld-link
lld-link-18
lldb
lldb-18
lldb-argdumper
lldb-argdumper-18
lldb-dap-18
lldb-instr-18
lldb-server
lldb-server-18
lli
lli-18
lli-child-target-18
llvm-PerfectShuffle
llvm-PerfectShuffle-18
llvm-addr2line
llvm-addr2line-18
llvm-ar
llvm-ar-18
llvm-as
llvm-as-18
llvm-bcanalyzer
llvm-bcanalyzer-18
llvm-bitcode-strip-18
llvm-c-test
llvm-c-test-18
llvm-cat
llvm-cat-18
llvm-cfi-verify
llvm-cfi-verify-18
llvm-config
llvm-config-18
llvm-cov
llvm-cov-18
llvm-cvtres
llvm-cvtres-18
llvm-cxxdump
llvm-cxxdump-18
llvm-cxxfilt
llvm-cxxfilt-18
llvm-cxxmap-18
llvm-debuginfo-analyzer-18
llvm-debuginfod-18
llvm-debuginfod-find-18
llvm-diff
llvm-diff-18
llvm-dis
llvm-dis-18
llvm-dlltool
llvm-dlltool-18
llvm-dwarfdump
llvm-dwarfdump-18
llvm-dwarfutil-18
llvm-dwp
llvm-dwp-18
llvm-exegesis
llvm-exegesis-18
llvm-extract
llvm-extract-18
llvm-gsymutil-18
llvm-ifs-18
llvm-install-name-tool-18
llvm-jitlink-18
llvm-jitlink-executor-18
llvm-lib
llvm-lib-18
llvm-libtool-darwin-18
llvm-link
llvm-link-18
llvm-lipo-18
llvm-lto
llvm-lto-18
llvm-lto2
llvm-lto2-18
llvm-mc
llvm-mc-18
llvm-mca
llvm-mca-18
llvm-ml-18
llvm-modextract
llvm-modextract-18
llvm-mt
llvm-mt-18
llvm-nm
llvm-nm-18
llvm-objcopy
llvm-objcopy-18
llvm-objdump
llvm-objdump-18
llvm-opt-report
llvm-opt-report-18
llvm-otool-18
llvm-pdbutil
llvm-pdbutil-18
llvm-profdata
llvm-profdata-18
llvm-profgen-18
llvm-ranlib
llvm-ranlib-18
llvm-rc
llvm-rc-18
llvm-readelf
llvm-readelf-18
llvm-readobj
llvm-readobj-18
llvm-readtapi-18
llvm-reduce
llvm-reduce-18
llvm-remarkutil-18
llvm-rtdyld
llvm-rtdyld-18
llvm-sim-18
llvm-size
llvm-size-18
llvm-split
llvm-split-18
llvm-stress
llvm-stress-18
llvm-strings
llvm-strings-18
llvm-strip
llvm-strip-18
llvm-symbolizer
llvm-symbolizer-18
llvm-tblgen
llvm-tblgen-18
llvm-tli-checker-18
llvm-undname
llvm-undname-18
llvm-windres-18
llvm-xray
llvm-xray-18
ln
lneato
localc
locale
locale-check
localectl
localedef
lodraw
loffice
lofromtemplate
logger
login
loginctl
logname
loimpress
loweb
lowriter
lp_solve
ls
lsattr
lsb_release
lsblk
lscpu
lsipc
lslocks
lslogins
lsmem
lsns
lsof
lspgpot
lstmeval
lstmtraining
lto-dump
lto-dump-13
luahbtex
lualatex
lualatex-dev
luatex
lwarpmk
lzcat
lzcmp
lzdiff
lzegrep
lzfgrep
lzgrep
lzless
lzma
lzmainfo
lzmore
m4
mag
make
make-first-existing-target
makedtx
makeglossaries
makeglossaries-lite
makeindex
makejvf
man
mathspic
mawk
mcookie
md5sum
md5sum.textutils
mendex
merge_unicharsets
mesg
mf
mf-nowin
mflua
mflua-nowin
mfplain
mft
mftraining
migrate-pubring-from-classic-gpg
mingle
mkdir
mkfifo
mkfontdir
mkfontscale
mkgrkindex
mkindex
mknod
mkocp
mkofm
mkpic
mktemp
mktexfmt
mktexlsr
mktexmf
mktexpk
mktextfm
mm2gv
modularize-18
modutil
mogrify
mogrify-im6
mogrify-im6.q16
montage
montage-im6
montage-im6.q16
more
mount
mountpoint
mpost
mptopdf
ms_print
msxlint
mv
namei
nano
nasm
nawk
nc
nc.openbsd
ncurses6-config
ncursesw6-config
ndisasm
neato
netcat
networkctl
newgrp
nice
ninja
nisdomainname
nl
nm
nohup
nop
nproc
nsenter
nss-addbuiltin
nss-dbtest
nss-pp
numfmt
nvptx-arch-18
obj2yaml
obj2yaml-18
objcopy
objdump
ocspclnt
od
odvicopy
odvitype
ofm2opl
omfonts
open
openssl
opl2ofm
opt
opt-18
osage
otangle
otp2ocp
outocp
ovf2ovp
ovp2ovf
p11-kit
p7content
p7env
p7sign
p7verify
pager
pandoc
paperconf
partx
passwd
paste
patch
patchwork
patgen
pathchk
pbibtex
pcre2-config
pdb3
pdb3.11
pdb3.12
pdb3.13
pdfannotextractor
pdfatfi
pdfattach
pdfclose
pdfdetach
pdfetex
pdffonts
pdfimages
pdfinfo
pdflatex
pdflatex-dev
pdfopen
pdfseparate
pdfsig
pdftex
pdftk
pdftk.pdftk-java
pdftocairo
pdftohtml
pdftoppm
pdftops
pdftosrc
pdftotext
pdfunite
pdvitomp
pdvitype
peekfd
perl
perl5.38-x86_64-linux-gnu
perl5.38.2
perlbug
perldoc
perlivp
perltex
perlthanks
pfb2pfa
pg_archivecleanup
pg_backupcluster
pg_basebackup
pg_buildext
pg_config
pg_conftool
pg_createcluster
pg_ctlcluster
pg_dropcluster
pg_dump
pg_dumpall
pg_isready
pg_lsclusters
pg_receivewal
pg_receivexlog
pg_recvlogical
pg_renamecluster
pg_restore
pg_restorecluster
pg_upgradecluster
pg_virtualenv
pgbench
pgrep
phar
phar.phar
phar.phar8.3
phar8.3
phar8.3.phar
php
php-config
php-config8.3
php8.3
phpize
phpize8.3
pico
piconv
pidof
pidwait
pinentry
pinentry-curses
pinky
pip
pip3
pip3.12
pipx
pk12util
pk1sign
pk2bm
pkaction
pkcheck
pkg-config
pkgconf
pkill
pktogf
pkttyagent
pktype
pl2pm
pldd
pltotf
pmap
pmpost
pmxab
pn2pdf
pod2html
pod2man
pod2text
pod2usage
podchecker
pooltype
pp-trace-18
ppltotf
pr
prepmx
printenv
printf
prlimit
prove
prtstat
prune
ps
ps2pk
pslog
psql
pstree
pstree.x11
ptar
ptardiff
ptargrep
ptex
ptftopl
ptx
pwd
pwdecrypt
pwdx
py3clean
py3compile
py3versions
pydoc3
pydoc3.11
pydoc3.12
pydoc3.13
pygettext3
pygettext3.11
pygettext3.12
pygettext3.13
pygmentex
python
python-argcomplete-check-easy-install-script
python3
python3-config
python3.11
python3.11-config
python3.12
python3.12-config
python3.13
python3.13-config
qpdf
qt-faststart
r-mpost
r-pmpost
r-upmpost
ranlib
rbash
readelf
readlink
realpath
redis-benchmark
redis-check-aof
redis-check-rdb
redis-cli
redis-server
register-python-argcomplete
reindexdb
rename.ul
renice
reset
resizepart
rev
rg
rgrep
rm
rmdir
rmiregistry
rnano
rpcgen
rsaperf
run-clang-tidy
run-clang-tidy-18
run-clang-tidy-18.py
run-parts
runc
runcon
rview
rvim
sancov-18
sanstats
sanstats-18
savelog
scalar
scan-build-18
scan-build-py-18
scan-view-18
sccmap
scor2prt
script
scriptlive
scriptreplay
sdiff
sed
select-default-iwrap
select-editor
selfserv
sensible-browser
sensible-editor
sensible-pager
sensible-terminal
seq
serialver
session-migration
set_unicharset_properties
setarch
setpriv
setsid
setterm
setxkbmap
sfconv
sfdp
sg
sh
sha1sum
sha224sum
sha256sum
sha384sum
sha512sum
shapeclustering
shasum
shlibsign
shred
shtool
shtoolize
shuf
signtool
signver
simpdftex
size
skill
slabtop
sleep
snice
soffice
sort
splain
split
splitindex
ssltap
stat
stdbuf
strace
strace-log-merge
stream
stream-im6
stream-im6.q16
streamzip
strings
strip
strsclnt
stty
su
sudo
sudoedit
sudoreplay
sum
svn-multi
symkeyutil
sync
synctex
systemctl
systemd
systemd-ac-power
systemd-analyze
systemd-ask-password
systemd-cat
systemd-cgls
systemd-cgtop
systemd-confext
systemd-creds
systemd-cryptenroll
systemd-cryptsetup
systemd-delta
systemd-detect-virt
systemd-escape
systemd-firstboot
systemd-id128
systemd-inhibit
systemd-machine-id-setup
systemd-mount
systemd-notify
systemd-path
systemd-repart
systemd-run
systemd-socket-activate
systemd-stdio-bridge
systemd-sysext
systemd-sysusers
systemd-tmpfiles
systemd-tty-ask-password-agent
systemd-umount
t1ascii
t1asm
t1binary
t1disasm
t1mac
t1unmac
t4ht
tabs
tac
tail
tangle
tar
taskset
teckit_compile
tee
tempfile
tesseract
test
tex
tex2aspc
tex4ht
texdoc
texdoctk
texhash
texlua
texluac
text2image
tftopl
thumbpdf
tic
tie
tikztosvg
timedatectl
timeout
tl-paper
tlmgr
tload
tmux
toe
tomlq
top
touch
tpic2pdftex
tput
tr
tred
true
truncate
trust
tset
tsort
tstclnt
ttf2afm
ttf2pk
ttf2tfm
ttfdump
tty
twill
twopi
txtconv
tzselect
ucf
ucfq
ucfr
uclampset
ucs2any
ulqda
umount
uname
uncompress
unexpand
unflatten
unicharset_extractor
uniq
unlink
unlzma
unminimize
unopkg
unshare
unxz
unzip
unzipsfx
upbibtex
update-alternatives
update-mime-database
updmap
updmap-sys
updmap-user
updvitomp
updvitype
upmendex
upmpost
uppltotf
uptex
uptftopl
uptime
users
utmpdump
vacuumdb
vacuumlo
valgrind
valgrind-di-server
valgrind-listener
valgrind.bin
varlinkctl
vdir
verify-uselistorder
verify-uselistorder-18
vftovp
vfychain
vfyserv
vgdb
vi
view
vim
vim.basic
vimdiff
vimdot
vimtutor
vlna
vmstat
vpe
vptovf
w
wall
wasm-ld
wasm-ld-18
watch
watchgnupg
wc
wdctl
weave
webquiz
wget
whereis
which
which.debianutils
who
whoami
wkhtmltoimage
wkhtmltopdf
wofm2opl
wopl2ofm
wordlist2dawg
wovf2ovp
wovp2ovf
x86_64
x86_64-linux-gnu-addr2line
x86_64-linux-gnu-ar
x86_64-linux-gnu-as
x86_64-linux-gnu-c++filt
x86_64-linux-gnu-cpp
x86_64-linux-gnu-cpp-13
x86_64-linux-gnu-dwp
x86_64-linux-gnu-elfedit
x86_64-linux-gnu-g++
x86_64-linux-gnu-g++-13
x86_64-linux-gnu-gcc
x86_64-linux-gnu-gcc-13
x86_64-linux-gnu-gcc-ar
x86_64-linux-gnu-gcc-ar-13
x86_64-linux-gnu-gcc-nm
x86_64-linux-gnu-gcc-nm-13
x86_64-linux-gnu-gcc-ranlib
x86_64-linux-gnu-gcc-ranlib-13
x86_64-linux-gnu-gcov
x86_64-linux-gnu-gcov-13
x86_64-linux-gnu-gcov-dump
x86_64-linux-gnu-gcov-dump-13
x86_64-linux-gnu-gcov-tool
x86_64-linux-gnu-gcov-tool-13
x86_64-linux-gnu-gi-compile-repository
x86_64-linux-gnu-gi-decompile-typelib
x86_64-linux-gnu-gi-inspect-typelib
x86_64-linux-gnu-gold
x86_64-linux-gnu-gp-archive
x86_64-linux-gnu-gp-collect-app
x86_64-linux-gnu-gp-display-html
x86_64-linux-gnu-gp-display-src
x86_64-linux-gnu-gp-display-text
x86_64-linux-gnu-gprof
x86_64-linux-gnu-gprofng
x86_64-linux-gnu-ld
x86_64-linux-gnu-ld.bfd
x86_64-linux-gnu-ld.gold
x86_64-linux-gnu-lto-dump
x86_64-linux-gnu-lto-dump-13
x86_64-linux-gnu-nm
x86_64-linux-gnu-objcopy
x86_64-linux-gnu-objdump
x86_64-linux-gnu-pkg-config
x86_64-linux-gnu-pkgconf
x86_64-linux-gnu-python3-config
x86_64-linux-gnu-python3.11-config
x86_64-linux-gnu-python3.12-config
x86_64-linux-gnu-python3.13-config
x86_64-linux-gnu-ranlib
x86_64-linux-gnu-readelf
x86_64-linux-gnu-size
x86_64-linux-gnu-strings
x86_64-linux-gnu-strip
xargs
xauth
xdg-desktop-icon
xdg-desktop-menu
xdg-email
xdg-icon-resource
xdg-mime
xdg-open
xdg-screensaver
xdg-settings
xdvi
xdvi-xaw
xdvi.bin
xdvipdfmx
xelatex
xelatex-dev
xetex
xkbbell
xkbcomp
xkbevd
xkbprint
xkbvleds
xkbwatch
xml2pmx
xmlcatalog
xmllint
xq-python
xsubpp
xvfb-run
xz
xzcat
xzcmp
xzdiff
xzegrep
xzfgrep
xzgrep
xzless
xzmore
yacc
yaml2obj
yaml2obj-18
yes
ypdomainname
yplan
yq
zcat
zcmp
zdiff
zdump
zegrep
zfgrep
zforce
zgrep
zip
zipcloak
zipdetails
zipgrep
zipinfo
zipnote
zipsplit
zless
zlib-flate
zmore
znew
single line
V.2
1 2 3 4
```

```
ARG [template [, template]...]
```
arg: an instruction that gets the arguments of a program, a routine, or a method as strings in upper, and puts them in variables
this instruction is the same as the code after this.
```
PARSE UPPER ARG [template [, template]...]
```
this instruction makes each argument object a string, and changes each letter in lower to upper, then it does a parse of the string.
after this instruction, there can be one template, or more than one template with a comma between two of them.
a template has symbols, patterns, or both, with blanks between them.
with more than one argument, the template after each comma is for the next argument.
you can use this instruction and parse arg more than one time on the same arguments; the arguments do not change.
to keep each letter as it is, use the instruction in the code after this.
```
PARSE ARG
```
the builtin function arg can also get the arguments.
use arg puts each argument object in a variable, with no change to a string and no parse.
the code:
```rexx
/* String passed is "Easy Rider"  */
Arg adjective noun .

/* Now:  ADJECTIVE  contains "EASY"           */
/*       NOUN       contains "RIDER"          */

/* Function is called by  FRED("data X",1,5)    */
Fred:  Arg string, num1, num2

/* Now:   STRING  contains "DATA X"             */
/*        NUM1    contains "1"                  */
/*        NUM2    contains "5"                  */
```
the result:
```
```

```
CALL routinename [expression] [, [expression]]...
CALL (expr) [expression] [, [expression]]...
CALL ON usercondition
CALL OFF usercondition
```
this instruction calls a routine, or it changes the trap of a condition.
with on, this instruction starts the trap of the condition; with off, it stops the trap.
the symbol after on or off is the name of the condition; it is one symbol, and it is a constant.
the name of the routine must be a literal or a symbol that is a constant.
the symbol can have a name and a colon before it.
the name can also be any expression in parentheses.
that expression runs before the expressions of the arguments.
the value of that expression does not change to upper, so each letter must be the same as in the label or in the name of the builtin function.
with a literal as the name, this instruction does not use an internal routine; it calls only a builtin function or an external routine.
the names of builtin functions are in upper, so that literal must be in upper too.
this instruction can call an internal routine: a subroutine in the same program, at a label.
this instruction can call a builtin function, as a subroutine.
this instruction can call an external routine: a routine that is not builtin and not at a label in the same program.
first, this instruction uses an internal routine with that name, if there is one; if not, a builtin function; if not, an external routine.
this instruction goes to the routine in the same way as a function call.
you can give any count of expressions as arguments, with a comma between two of them.
the expressions run in order, from left to right, and the arguments are the values.
in the routine, arg, parse arg, use arg, or the builtin function arg can get the arguments.
you can omit an argument: put one more comma.
if the return instruction of the routine has an expression, the variable result gets its value.
if not, the variable result has no value; it is uninitialized.
when you call a builtin function as a subroutine, its result goes in the variable result.
after the return instruction, the program runs the clause after the call.
a return instruction ends an internal routine.
an exit instruction can return from an external routine.
an internal routine can call other internal routines, and it can call the same routine again from in it.
an internal routine can use all the variables known before the call.
with the procedure instruction, the variables of an internal routine are local; the expose option of procedure can make some variables of the caller known to it.
an external routine can not use the variables of the caller.
```
NUMERIC DIGITS    NUMERIC FUZZ    NUMERIC FORM
```
an external routine starts with the default values of the things in the code before this, not with the values of the caller.
after an internal routine, the things in the code before this are the same as before the call.
```
SIGL
```
this instruction puts the number of the line of the call in the variable in the code before this, in the variables of the caller.
if the internal routine uses procedure, it must expose that variable to use it.
the call does not end a loop or a group that runs at the call.
a loop or a group that starts in the subroutine ends when the subroutine ends.
a signal instruction in a subroutine does not change a loop or a group of the caller.
after an internal routine, the trace is the same as before the call, also if the trace is interactive.
after an internal routine, the two environment names of address, and where they get input and put output, are the same as before the call.
after an internal routine, the traps that call on and signal on start are the same as before the call.
call on, call off, signal on, and signal off in a subroutine do not change the traps of the caller.
after an internal routine, the data about the condition now is the same as before the call; the builtin function condition gives this data.
```
.RS
```
after an internal routine, the value of the environment symbol in the code before this is the same as before the call.
the code:
```rexx
call length "string"   /* Same as length("string") */
say result             /* Produces: 6              */

/* Recursive subroutine execution... */
arg z
call factorial z
say z"! =" result
exit
factorial: procedure     /* Calculate factorial by  */
  arg n                  /*  recursive invocation.  */
  if n=0 then return 1
  call factorial n-1
  return  result * n
```
the result:
```
41.1
```

```
DO [LABEL name]
   [instruction]...
END [name]
```
form: a way to write an instruction
this instruction makes a group of instructions; in some ways, it runs the group more than one time.
in this form, there is no part to repeat the group and no condition, so this instruction only makes a group of instructions.
in this form, the group runs one time.
```
COUNTER
```
you can not use the keyword in the code before this on a group that does not repeat.
each instruction in the group can be any instruction: an assignment, a command, a message instruction, or a keyword instruction, as if, do, or loop.
the code:
```rexx
/* The two instructions between DO and END are both  */
/* processed if A has the value "3".                 */
If a=3 then Do
   a=a+2
   Say "Smile!"
End
```
the result:
```
```

```
DO [LABEL name] [COUNTER ctr] exprr [conditional]
DO [LABEL name] [COUNTER ctr] FOREVER [conditional]
DO [LABEL name] [COUNTER ctr] conditional
   [instruction]...
END [name]
```
in the first form, the expression after do gives the count of times the group runs.
that expression runs one time, at the start, before the group runs.
its value must be a whole number that is zero or positive.
that number is rounded with the precision now.
then the group runs that count of times.
control: a control variable is the variable of a loop that gets a new value each time the loop runs its group
if the first token of the expression is a symbol, and the second token is an equal mark or starts with one, this instruction is not this form: it is the form with a control variable.
```
FOREVER
```
with the keyword in the code before this, or with no part to repeat but with a condition, the group runs until the condition ends the loop or an instruction as leave ends the loop.

```
DO [LABEL name] [COUNTER ctr] control1=expri [TO exprt] [BY exprb] [FOR exprf] [conditional]
   [instruction]...
END [control1]
```
in this form, the symbol before the equal mark is the control variable.
the control variable must be a symbol that can be the name of a variable.
the control variable gets the value of the expression after the equal mark, as if you add zero to it, before the group runs the first time.
before the second time and each next time, the loop adds the value after by to the control variable.
the expressions after the equal mark, after to, and after by must give numbers.
these three expressions each run one time, before the loop starts and before the control variable gets its first value.
the expression after for runs one time, when the instruction starts, before the control variable gets its first value.
the numbers are rounded with the precision now.
the default value after by is 1.
the value after by can be positive, zero, or negative.
if the value after by is zero or positive, the loop ends when the control variable is more than the value after to.
if the value after by is negative, the loop ends when the control variable is less than the value after to.
if you omit to, the loop does not end from it; an other thing must end the loop.
the loop tests if it must end at the start of each time the group runs; from the second time, it tests after it adds to the control variable.
if the loop must end at the first test, the group does not run one time.
the value after for must be a whole number that is zero or positive.
the value after for is a count of times: the loop ends after that count, if no other thing ends it first.
the loop tests the count after for at the start of each time.
to, by, and for can be in any order, and they run in the order you write them.
the loop uses the name of the control variable: if the control variable is a compound symbol, a change to a variable in its tail changes what variable is the control variable.
the group can change the control variable.
the precision of maths can change the values that the control variable gets.
the values of the control variable do not have to be whole numbers.
you can put the name of the control variable after end.
that name must be the same as the name of the control variable, with any letter in upper or lower.
for a compound name after end, the tail does not change to the values of its variables.
if the name after end is not the same, it is an error.
so the name after end tests the order of a nested loop.
the code:
```rexx
I=0.3                     /* Displays:   */
Do Y=I to I+4 by 0.7      /*     0.3     */
  say Y                   /*     1.0     */
end                       /*     1.7     */
                          /*     2.4     */
                          /*     3.1     */
                          /*     3.8     */
```
the result:
```
0.3
1.0
1.7
2.4
3.1
3.8
```

```
DO [LABEL name] [COUNTER ctr] control2 OVER collection [conditional]
   [instruction]...
END [control2]
```
in this form, the control variable gets a new value each time the group runs; the values are from the collection.
the collection is any expression that gives an object that has a method to make an array, as a stem variable.
the array that the method gives says the values and the order of the values.
an array, a list, a queue, and a stream give the items in order.
a table, a stem, and a directory give the items in no order.
for a stem, each value is a tail that the program assigned a value to in that stem.
for a stem, the order of the values is not known, and a program must not use that order.
for other collections, the method of the collection to make an array says the values the control variable gets.
the loop gets all the values at the start of the loop.
so a change to the collection in the loop does not change the count of times or the values.
a drop of a tail of the stem, or a new tail, in the loop does not change the count of times or the values.
you can put the name of the control variable after end or after leave.
the loop uses the control variable by its name, and the group can change it.

```
DO [LABEL name] [COUNTER ctr] WITH [INDEX index] [ITEM item] OVER supplier [conditional]
   [instruction]...
END [name]
```
in this form, there are one or two control variables, the index and the item; they get new values each time the group runs.
the values are from the supplier: any expression that gives an object that has a supplier method.
the supplier says the values and the order of the values.
the loop gets all the values at the start of the loop.
so a change to the object in the loop does not change the values.
the index and the item can be in any order; you can use each one only one time.
the index and the item must be symbols that can be names of variables.
to name this loop after end or after leave, you must use the label keyword.

```
DO [LABEL name] [COUNTER ctr] [repetitor] WHILE exprw [, exprw]...
DO [LABEL name] [COUNTER ctr] [repetitor] UNTIL expru [, expru]...
   [instruction]...
END [name]
```
a condition after while or until can change how the loop runs, or end the loop.
the condition can come after no part to repeat, or after any part to repeat.
the expression must give 1 or 0.
the condition can be a list of expressions with a comma between two of them.
the list runs from left to right; it stops at the first 0, and then the condition is 0.
if all the expressions in the list give 1, the condition is 1.
the condition runs with the values the variables have at that time.
the while condition runs at the start of each time the group runs.
the loop ends when the while condition is 0.
the until condition runs at the end of each time the group runs, before the control variable gets its next value.
the loop ends when the until condition is 1.
the leave instruction can also change how a loop runs.

```
DO LABEL name [COUNTER ctr] [repetitor] [conditional]
   [instruction]...
END [name]
```
in this form, the label keyword gives a name to the do or the loop.
the label is optional.
you can use the label on a leave instruction, to say what group to end.
you can use the label after end, as a test.
with a label, the name of the control variable can not name the loop on leave or after end; only the label can.

```
DO [LABEL name] COUNTER ctr repetitor [conditional]
DO [LABEL name] COUNTER ctr conditional
   [instruction]...
END [name]
```
counter: a variable that has the count of times a loop runs its group; also the keyword that gives the name of that variable
you can use the counter keyword on a do or a loop with a part to repeat or a condition.
you can not use the counter keyword on a group that does not repeat.
the counter must be a symbol that can be the name of a variable.
the counter is 1 the first time the group runs, and it is 1 more each next time.
after the loop, the counter is the count of all times the group runs.
if the group does not run, the counter is 0.
the label keyword and the counter keyword can be in any order, and they must come before the part to repeat and before the condition.
the code:
```rexx
do counter ct x = -0.3 to 0.4 by 0.2
  say ct x
end
/* Displays: 1 -0.3, 2 -0.1, 3 0.1, 4 0.3 */
```
the result:
```
1 -0.3
2 -0.1
3 0.1
4 0.3
```

```
DROP name [name]...
DROP (name) [name]...
```
this instruction makes each variable you name uninitialized, as at the start.
each name is a symbol that must be a name of a variable.
there are blanks, or a comment, between two names.
with one name in parentheses, the value of that variable is a list of more variables to drop.
you can put blanks in or outside the parentheses, or not.
the list in that variable has the same rules, but it can not have parentheses.
that list can be empty.
this instruction does not drop the variable in parentheses.
a stem is a symbol with only one point, and that point is its last character.
when you drop a stem, the stem variable gets a new empty stem object.
the variables drop in order from left to right.
to name a variable more than one time is not an error.
to drop a variable that is not known is not an error.
if you name an exposed variable, this instruction does a drop of the variable in the pool it is from.
after the drop, the value of the variable is its name.
the code:
```rexx
j=4
Drop  a z.3 z.j
/* Drops the variables: A, Z.3, and Z.4              */
/* so that reference to them returns their names.    */

mylist="c d e"
drop (mylist) f
/* Drops the variables C, D, E, and F          */
/* Does not drop MYLIST                        */

Drop  z.
/* Assigns stem variable z. to a new empty stem object */
```
the result:
```
```

```
EXIT [expression]
```
this instruction ends the program now, also when an internal routine runs.
this instruction can give a result object to the caller.
when no internal routine runs, return and exit do the same thing.
with an expression, the expression runs, and the object it gives goes to the caller when the program ends.
with no expression, no data goes back to the caller.
if the caller uses the program as a function, and this instruction has no expression, it is an error.
in a method, this instruction ends the method now, and gives the result, if there is one, to the caller.
if a method used reply, its exit instruction must not have an expression.
if the caller runs the program as a command, the value is a whole number from -32768 to 32767 that goes back to the shell.
if the value is not a whole number in that range, it is not an error, and the number that goes back is 0.
```
Unix-like systems
```
on a computer of the kind in the code before this, the number that goes back can only be from 0 to 255.
if the program has no exit instruction, it ends at its end, and it gives no result.
the code:
```rexx
j=3
Exit j*4
/* Would exit with the string "12" */
```
the result:
```
```

```
EXPOSE name [name]...
EXPOSE (name) [name]...
```
this instruction makes the object variables you name known to the method.
a use of an exposed variable, also an assignment or a drop, uses the variable pool of the object now.
the pool of the object variables is a part of the object, not of one method.
after return or exit, an exposed variable keeps the change.
other methods with the same scope can use the new value now.
a variable that the method uses but does not expose is local to the method, and after return or exit, it has no value.
if you use this instruction, it must be the first instruction of the method.
no label can come before this instruction.
with one name in parentheses, this instruction first does an expose of that variable, then the value of it is a list of more variables to expose.
you can put blanks in or outside the parentheses, or not.
the list in that variable has the same rules, but it can not have parentheses.
the variables are exposed in order from left to right.
to name a variable more than one time is not an error.
to name a variable that is not used yet is not an error.
with a stem in the list, all the compound variables of that stem are exposed.
the code:
```rexx
/* Example of exposing object variables */
myobj = .myclass~new
myobj~c
myobj~d         /* Would display "Z is: 120"                 */

::class myclass /* The ::CLASS directive                     */
::method c      /* The ::METHOD directive                    */
  expose z
  z = 100       /* Would assign 100 to the object variable z */
  return

::method d
  expose z
  z=z+20        /* Would add 20 to the same object variable z */
  say "Z is:" z
  return

::method mymethod
expose j k  c. d.
/*  This exposes "J", "K", and all variables whose            */
/*  name starts with "C." or "D."                             */
c.1="7."        /*  This sets "C.1" in the object             */
                /*  variable pool, even if it did not         */
                /*  previously exist.                         */
```
the result:
```
Z is: 120
```

```
FORWARD [TO exprt] [MESSAGE exprm] [ARGUMENTS expra | ARRAY expri [, expri]...] [CLASS exprs] [CONTINUE]
```
forward: an instruction in a method that sends again the message of the method, or a part of it, to an other method
this instruction can send again a message that a method gets to an other object.
you can give the options in any order.
the value after to is the object that gets the message.
the name of the message is the value after message, in upper.
the value after arguments must be an array; the items of the array are the arguments.
after array is a list of expressions with a comma between two of them; the values of them are the arguments.
the value after class is the class to use as the superclass.
the values after to, message, arguments, and class are each a literal, a constant symbol, an environment symbol, or an expression in parentheses.
if you omit to, the object that gets the message is the first value of self.
if you omit arguments and array, the message has the same arguments as the message of the method now.
if you omit message, the name of the message is the name of the message that runs the method now.
if you omit class, the message does not name a superclass.
to use both array and arguments in one instruction is an error.
```
CONTINUE
```
with the keyword in the code before this, the method does not end: it runs the next instruction when the message gives its result.
then the variable result gets the result; if there is no result, the variable result is uninitialized.
without that keyword, the method ends before it sends the message.
then the result of the message is the result of the first call of the method.
then an event from the message is raised in the caller, not in the method.
```
UNKNOWN
```
a method with the name in the code before this can use this instruction to send the message it gets to an other object.
an init method can use this instruction to send the message to its superclass with the same arguments.
the code:
```rexx
::method substr
  forward to (self~string)       /* Forward to the string value */

::method unknown
  use arg msg, args
  /* Forward to the string value */
  /* passing along the arguments */
  forward to (self~string) message (msg) arguments (args)

::class  savings subclass account
::method init
  expose type penalty
  forward class (super) continue       /* Send to the superclass      */
  type = "Savings"                     /* Now complete initialization */
  penalty = "1% for balance under 500"
```
the result:
```
98.909
```

```
GUARD ON [WHEN expression [, expression]...]
GUARD OFF [WHEN expression [, expression]...]
```
guard on gives the method that runs now the only use of the variable pool of its object.
then other methods that need that pool must wait.
if an other method has that use now, the method waits.
guard off ends that use, so other methods can run.
with when, the method does not run more until the expression is true.
if the expression is false, the method waits until an other method assigns or does a drop of an object variable that the expression uses.
the condition can be a list of expressions with a comma between two of them.
the list runs from left to right; it stops at the first false value, and then the condition is false.
if all the expressions in the list are true, the condition is true.
the expression can use local variables and object variables.
the expression must use one or more object variables that the method exposed by use local or by expose, with a name that is not in parentheses.
the expression runs again only when an object variable changes; if it is true, the method runs, and if it is false, the method waits more.
if the method has the only use of the pool, it ends that use while it waits, and it gets that use again before the expression runs.
when the expression is true, guard on with when keeps the only use of the pool, and guard off with when ends it.
if the condition is never true, guard on with when waits with no end.
this can be so when more than one activity runs at the same time.
the code:
```rexx
c = .Concurrent~new
c~work

::class Concurrent
::method init
  expose ready
  ready = .false
  reply
  call SysSleep 1 -- long-running initialization
  ready = .true

::method work unguarded
  expose ready
  guard on when ready -- wait until initialized
  say "starting work"
```
the result:
```
starting work
```

```
IF expression [, expression]... THEN instruction
[ELSE instruction]
```
this instruction runs an instruction, or a group of instructions, if an expression is true.
the expression must give 0 or 1: false or true.
there can be a list of expressions with a comma between two of them.
the list runs from left to right, and each expression in it must give 0 or 1.
the list stops at the first 0, and then the condition is 0.
if all the expressions in the list give 1, the condition is 1.
the instruction after then runs only if the condition is true.
if there is an else, the instruction after else runs only if the condition is false.
if else is on the same line as the last clause after then, you must put a semicolon before else.
then does not have to start a clause, so the expression can end at then with no semicolon.
then can not be in an expression, but it can be in a part of an expression in parentheses.
the instruction after then or after else can be any assignment, message instruction, command, or keyword instruction, also do, loop, or if.
a null clause is not an instruction: a semicolon or a label after then or after else is not an instruction.
```
NOP
```
the instruction in the code before this does no thing; use it where there must be an instruction.
with nested if instructions, use that instruction to say what if each else is a part of.
```
&
```
the operator in the code before this runs both operands, so an error in the second operand is an error also when the first is 0.
a list of expressions stops at the first 0, so the next expressions in the list do not run.
the code:
```rexx
if answer="YES" then say "OK!"
else say "Why not?"

if answer="YES" then say "OK!";  else say "Why not?"

If answer = "YES" Then
  If name = "FRED" Then
    say "OK, Fred."
  Else
    nop
Else
  say "Why not?"

If answer~datatype('w'), answer//2 = 0 Then
  say answer "is even"
Else
  say answer "is odd"

If answer~datatype('w') & answer//2 = 0 Then
  say answer "is even"
Else
  say answer "is odd"
```
the result:
```
41.1
```

```
INTERPRET expression
```
interpret: an instruction that runs the value of an expression as rexx code
the expression gives a string, and this instruction runs the string as a line of the program, between do and end.
if the string does not end with a semicolon, this instruction runs it as if it has one.
the string can have any instructions, also this instruction.
a do and its end must both be in the string.
```
SELECT ... END
```
the instruction in the code before this and its end must also both be in the string.
```
LEAVE    ITERATE
```
the instructions in the code before this can be in the string only if the loop of each of them is all in the string.
a label in the string is not there after the string runs, and to use it is an error.
a directive can not be in the string.
the builtin function value can do the same thing as this instruction many times.
you need this instruction only to run more than one instruction as one, or to run an expression that the program makes when it runs.
```
TRACE R    TRACE I
```
you can use the trace in the code before this to read the results of this instruction.
in a trace, the code from the string is new clauses.
the code:
```rexx
/* INTERPRET example */
data="FRED"
interpret data "= 4"
/* Builds the string  "FRED = 4" and        */
/* Processes:  FRED = 4;                    */
/* Thus the variable FRED is set to "4"     */

/* Another INTERPRET example */
data="do 3; say "Hello there!"; end"
interpret data        /* Displays:          */
                      /*  Hello there!      */
                      /*  Hello there!      */
                      /*  Hello there!      */

/* Here is a small Rexx program. */
Trace Int
name="Kitty"
indirect="name"
interpret 'say "Hello"' indirect'"!"'
```
the result:
```
HELLO THERE!
HELLO THERE!
HELLO THERE!
Hello Kitty!
```
the reference says:
```
Hello Kitty!
```

the code:
```rexx
indirect="name"  /* setup from the example before */
say "Hello" value(indirect)"!"
```
the result:
```
Hello NAME!
```
the reference says:
```
Hello Kitty!
```

```
ITERATE [name]
```
iterate: an instruction that ends this time of a loop and goes to the next time
active: a loop is active while it runs; while it waits for a subroutine or for an interpret instruction to end, it is not active
this instruction stops the group that runs now and goes back to the do or loop instruction, as if at the end.
the control variable, if there is one, gets its next value, and the loop tests it as at each time.
then the group runs again, if the do or loop instruction does not end the loop.
the name is a symbol, and it is a constant.
with no name, this instruction goes on with the active loop that runs now.
with a name, the name must be the name of the control variable or the label of an active loop.
the loop with that name is the one that gets its next time.
each active loop in that loop ends, as with leave.
the name must be the same as the name of the control variable or the label, with any letter in upper or lower.
for a compound name, the tail does not change to the values of its variables.
this instruction can not go on with a loop that is not active.
if more than one active loop has the same name, this instruction uses the one that is nested in each other one.
the code:
```rexx
loop label MyLabelName i=1 to 4 /* label set to 'MYLABELNAME' */
  if i=2 then iterate
  say i
end myLabelName
/* Displays the numbers:
  1
  3
  4
*/
```
the result:
```
1
3
4
```

```
LEAVE [name]
```
this instruction ends an active loop or an active group now, and it can end more than one.
it can end a loop, a do group that does not repeat, or a group of the instruction in the code after this.
```
SELECT
```
the group ends, and the program runs the clause after the end of that group, as if the end condition is true.
the name is a symbol, and it is a constant.
with no name, this instruction ends the active loop that is nested in each other one.
with a name, the name must be the name of the control variable or the label of an active loop, do, or group of the instruction in the code before this.
then this instruction ends that group, and each active group in it.
after this instruction, the control variable keeps the value it has when this instruction runs.
the name must be the same as the name of the control variable or the label, with any letter in upper or lower.
for a compound name, the tail does not change to the values of its variables.
if more than one active group has the same control variable, this instruction uses the one that is nested in each other one.
this instruction can not end a group that is not active.
the code:
```rexx
max=5
do label myDoBlock /* define a label 'MYDOBLOCK' */
  loop i=1 to max /* label defaults to control variable 'I' */
    if i = 2 then iterate i
    if i = 4 then leave myDoBlock
    say i
  end i
end myDoBlock
say 'after looping' i 'times'
/* Displays the following
  1
  3
  after looping 4 times
*/
```
the result:
```
1
3
after looping 4 times
```

```
LOOP [LABEL name]
   [instruction]...
END [name]
```
this instruction makes a group of instructions and runs it more than one time.
this instruction is the same as do, but not in this form.
in this form, with no part to repeat and no condition, this instruction is the same as the code after this.
```
DO FOREVER
   [instruction]...
END
```

```
LOOP [LABEL name] [COUNTER ctr] exprr [conditional]
LOOP [LABEL name] [COUNTER ctr] FOREVER [conditional]
LOOP [LABEL name] [COUNTER ctr] conditional
   [instruction]...
END [name]
```
in this form, this instruction is the same as do in the same form.
the code:
```rexx
/* This displays "Hello" five times */
Loop 5
say "Hello"
end
```
the result:
```
Hello
Hello
Hello
Hello
Hello
```

```
LOOP [LABEL name] [COUNTER ctr] control1=expri [TO exprt] [BY exprb] [FOR exprf] [conditional]
   [instruction]...
END [control1]
```
in this form, this instruction is the same as do in the same form.
the code:
```rexx
Loop I=3 to -2 by -1      /* Displays:   */
  say i                   /*      3      */
end                       /*      2      */
                          /*      1      */
                          /*      0      */
                          /*     -1      */
                          /*     -2      */

Loop Y=0.3 to 4.3 by 0.7 for 3  /* Displays:    */
  say Y                         /*     0.3      */
end                             /*     1.0      */
                                /*     1.7      */

Loop K=1 to 10
...
...
End k  /* Checks that this is the END for K loop */
```
the result:
```
3
2
1
0
-1
-2
0.3
1.0
1.7
```

```
LOOP [LABEL name] [COUNTER ctr] control2 OVER collection [conditional]
   [instruction]...
END [control2]
```
in this form, this instruction is the same as do in the same form.
in the code after this, the order of the two lines of output is not known.
the code:
```rexx
Astem.=0
Astem.3="CCC"
Astem.24="XXX"
loop k over Astem.
   say k Astem.k
end k
/* can produce:   */
/*   3 CCC        */
/*   24 XXX       */
/* or:            */
/*   24 XXX       */
/*   3 CCC        */
```
the result:
```
24 XXX
3 CCC
```

```
LOOP [LABEL name] [COUNTER ctr] WITH [INDEX index] [ITEM item] OVER supplier [conditional]
   [instruction]...
END [name]
```
in this form, this instruction is the same as do in the same form.
the code:
```rexx
loop with index name item method over .numericComparator~methods(.nil)
  say name method~isPrivate method~isProtected method~isGuarded
end
/* can produce:   */
/*   COMPARE 0 0 1 */
/*   INIT 0 0 1    */
```
the result:
```
COMPARE 0 0 1
INIT 0 0 1
```

```
LOOP [LABEL name] [COUNTER ctr] [repetitor] WHILE exprw [, exprw]...
LOOP [LABEL name] [COUNTER ctr] [repetitor] UNTIL expru [, expru]...
   [instruction]...
END [name]
```
in this form, this instruction is the same as do in the same form.
the code:
```rexx
Loop I=1 to 10 by 2 until i>6
   say i
end
/* Displays: "1" "3" "5" "7" */
```
the result:
```
1
3
5
7
```

```
LOOP LABEL name [COUNTER ctr] [repetitor] [conditional]
   [instruction]...
END [name]
```
in this form, this instruction is the same as do in the same form.
you can use the label on an iterate instruction, to say what loop goes to its next time.
with a label, the name of the control variable can not name the loop on iterate.
the code:
```rexx
Loop label outer I=1 to 10 by 2
   ...
   if i > 5 then do label inner
      ...
      if a = b then leave inner
      ...
      if c = b then iterate outer
   end inner
   ...
   say i
end outer
/* Displays: "1" "3" "5" "7" */
```
the result:
```
1
3
5
7
9
```

```
LOOP [LABEL name] COUNTER ctr repetitor [conditional]
LOOP [LABEL name] COUNTER ctr conditional
   [instruction]...
END [name]
```
in this form, this instruction is the same as do in the same form.

