# Makefile to build the entire dlang.org website
#
# To run:
#
# make -f posix.mak all
#
# To also upload to the website:
#
# make -f posix.mak rsync
#

# Externals
DMD_DIR=../dmd
PHOBOS_DIR=../phobos
DRUNTIME_DIR=../druntime
DUB_DIR=../dub-${DUB_VER}
DMD=$(DMD_DIR)/src/dmd
DMD_REL=$(DMD_DIR)-${LATEST}/src/dmd
DUB=${DUB_DIR}/bin/dub
DOC_OUTPUT_DIR:=$(shell pwd)/web
GIT_HOME=https://github.com/D-Programming-Language
DPL_DOCS_PATH=dpl-docs
DPL_DOCS=$(DPL_DOCS_PATH)/dpl-docs
REMOTE_DIR=d-programming@digitalmars.com:data
# stable dub and dmd versions used to build dpl-docs
DUB_VER=0.9.22
STABLE_DMD_VER=2.066.1
STABLE_DMD_ROOT=/tmp/.stable_dmd-$(STABLE_DMD_VER)
STABLE_DMD_URL=http://downloads.dlang.org/releases/2014/dmd.$(STABLE_DMD_VER).$(OS).zip
STABLE_DMD=$(STABLE_DMD_ROOT)/dmd2/$(OS)/$(if $(filter $(OS),osx),bin,bin$(MODEL))/dmd

# rdmd must fetch the model, imports, and libs from the specified version
DFLAGS=-m$(MODEL) -I$(DRUNTIME_DIR)/import -I$(PHOBOS_DIR) -L-L$(PHOBOS_DIR)/generated/$(OS)/release/$(MODEL)
RDMD=rdmd --compiler=$(DMD) $(DFLAGS)

# Tools
REBASE = MYBRANCH=`git rev-parse --abbrev-ref HEAD` &&\
 git co master &&\
 git pull --ff-only upstream master &&\
 git co $$MYBRANCH &&\
 git rebase master

# Latest released version
ifeq (,${LATEST})
LATEST:=$(shell cd ${DMD_DIR} && \
  git fetch --tags ${GIT_HOME}/dmd && \
  git tag | grep '^v[0-9][0-9.]*$$' | sed 's/^v//' | sort -nr | head -n 1)
endif
ifeq (,${LATEST})
  $(error Could not fetch latest version)
endif
$(info Current release: ${LATEST})

# OS and MODEL
OS:=
uname_S:=$(shell uname -s)
ifeq (Darwin,$(uname_S))
    OS:=osx
endif
ifeq (Linux,$(uname_S))
    OS:=linux
endif
ifeq (FreeBSD,$(uname_S))
    OS:=freebsd
endif
ifeq (OpenBSD,$(uname_S))
    OS:=openbsd
endif
ifeq (Solaris,$(uname_S))
    OS:=solaris
endif
ifeq (SunOS,$(uname_S))
    OS:=solaris
endif
ifeq (,$(OS))
    $(error Unrecognized or unsupported OS for uname: $(uname_S))
endif

ifeq (,$(MODEL))
    uname_M:=$(shell uname -m)
    ifneq (,$(findstring $(uname_M),x86_64 amd64))
        MODEL:=64
    endif
    ifneq (,$(findstring $(uname_M),i386 i586 i686))
        MODEL:=32
    endif
    ifeq (,$(MODEL))
        $(error Cannot figure 32/64 model from uname -m: $(uname_M))
    endif
endif

# Documents

DDOC=macros.ddoc html.ddoc dlang.org.ddoc doc.ddoc ${LATEST}.ddoc $(NODATETIME)

IMAGES=favicon.ico $(addprefix images/, apple_logo.png c1.gif		\
centos_logo.png cpp1.gif d002.ico d3.png d4.gif d5.gif			\
debian_logo.png dlogo.png dmlogo.gif dmlogo-smaller.gif download.png	\
fedora_logo.png freebsd_logo.png github-ribbon.png gradient-green.jpg	\
gradient-red.jpg globe.gif opensuse_logo.png pen.gif search-left.gif	\
search-bg.gif search-button.gif tdpl.jpg ubuntu_logo.png		\
windows_logo.png) $(addprefix images/ddox/, alias.png class.png		\
enum.png enummember.png function.png inherited.png interface.png	\
module.png package.png private.png property.png protected.png		\
struct.png template.png tree-item-closed.png tree-item-open.png		\
variable.png)

JAVASCRIPT=$(addprefix js/, codemirror-compressed.js listanchors.js run.js	\
run-main-website.js ddox.js)

STYLES=css/style.css css/print.css css/codemirror.css css/ddox.css

PRETTIFY=prettify/prettify.css prettify/prettify.js

PREMADE=appendices.html articles.html fetch-issue-cnt.php	\
howtos.html language-reference.html robots.txt process.php

# Language spec root filenames. They have extension .dd in the source
# and .html in the generated HTML. These are also used for the mobi
# book generation, for which reason the list is sorted by chapter.
SPEC_ROOT=spec intro lex grammar module declaration type property attribute pragma	\
	expression statement arrays hash-map struct class interface enum	\
	const3 function operatoroverloading template template-mixin contracts		\
	version traits errors unittest garbage float iasm ddoc				\
	interfaceToC cpp_interface portability entity memory-safe-d abi		\
	simd

# Website root filenames. They have extension .dd in the source
# and .html in the generated HTML. Save for the expansion of
# $(SPEC_ROOT), the list is sorted alphabetically.
PAGES_ROOT=$(SPEC_ROOT) 32-64-portability acknowledgements ascii-table		\
	bugstats.php builtin changelog code_coverage concepts const-faq COM	\
	comparison cpptod ctod D1toD2 d-array-article d-floating-point		\
	deprecate dll dll-linux dmd-freebsd dmd-linux dmd-osx dmd-windows	\
	download dstyle exception-safe faq features2 glossary gsoc2011 gsoc2012	\
	gsoc2012-template hijack howto-promote htod htomodule index intro	\
	intro-to-datetime lazy-evaluation memory migrate-to-shared mixin	\
	overview pretod rationale rdmd regular-expression safed			\
	std_consolidated_header template-comparison templates-revisited tuple	\
	variadic-function-templates warnings wc windbg windows

TARGETS=$(addsuffix .html,$(PAGES_ROOT))

ALL_FILES_BUT_SITEMAP = $(addprefix $(DOC_OUTPUT_DIR)/, $(TARGETS)	\
$(PREMADE) $(STYLES) $(IMAGES) $(JAVASCRIPT) $(PRETTIFY))

ALL_FILES = $(ALL_FILES_BUT_SITEMAP) $(DOC_OUTPUT_DIR)/sitemap.html

# Pattern rulez

$(DOC_OUTPUT_DIR)/%.html : %.dd $(DDOC) $(DMD)
	$(DMD) -c -o- -Df$@ $(DDOC) $<

$(DOC_OUTPUT_DIR)/%.php : %.php.dd $(DDOC) $(DMD)
	$(DMD) -c -o- -Df$@ $(DDOC) $<

$(DOC_OUTPUT_DIR)/% : %
	@mkdir -p $(dir $@)
	cp $< $@

$(DOC_OUTPUT_DIR)/dmd-%.html : %.ddoc dcompiler.dd $(DDOC) $(DMD)
	$(DMD) -c -o- -Df$@ $(DDOC) dcompiler.dd $<

################################################################################
# Rulez
################################################################################

all : docs html

docs : phobos-prerelease druntime-prerelease druntime-release phobos-release	\
	apidocs-release apidocs-prerelease

html : $(ALL_FILES)

kindle : ${DOC_OUTPUT_DIR}/dlangspec.mobi

pdf : ${DOC_OUTPUT_DIR}/dlangspec.pdf

$(DOC_OUTPUT_DIR)/sitemap.html : $(ALL_FILES_BUT_SITEMAP) $(DMD)
	cp -f sitemap-template.dd sitemap.dd
	(true $(foreach F, $(TARGETS), \
	  && echo \
        "$F\t`sed -n 's/<title>\(.*\) - D Programming Language.*<\/title>/\1/'p $(DOC_OUTPUT_DIR)/$F`")) \
	  | sort --ignore-case --key=2 | sed 's/^\([^	]*\)	\(.*\)/<a href="\1">\2<\/a><p>/' >> sitemap.dd
	$(DMD) -c -o- -Df$@ $(DDOC) sitemap.dd
	rm -rf sitemap.dd

${LATEST}.ddoc :
	echo "LATEST=${LATEST}" >$@

# Run "make -j rebase" for rebasing all dox in parallel!
rebase: rebase-dlang rebase-dmd rebase-druntime rebase-phobos
rebase-dlang: ; $(REBASE)
rebase-dmd: ; cd $(DMD_DIR) && $(REBASE)
rebase-druntime: ; cd $(DRUNTIME_DIR) && $(REBASE)
rebase-phobos: ; cd $(PHOBOS_DIR) && $(REBASE)

clean:
	rm -rf $(DOC_OUTPUT_DIR) ${LATEST}.ddoc dpl-docs/.dub
	rm -rf auto dlangspec-consolidated.d $(addprefix dlangspec,.aux .d .dvi .fdb_latexmk .fls .log .out .pdf .tex .txt .verbatim.txt)
	rm -f docs.json docs-prerelease.json dpl-docs/dpl-docs 
	@echo You should issue manually: rm -rf ${DMD_DIR}-${LATEST} ${DRUNTIME_DIR}-${LATEST} ${PHOBOS_DIR}-${LATEST} ${STABLE_DMD_ROOT} ${DUB_DIR}

rsync : all kindle pdf
	rsync -avz $(DOC_OUTPUT_DIR)/ $(REMOTE_DIR)/

rsync-only :
	rsync -avz $(DOC_OUTPUT_DIR)/ $(REMOTE_DIR)/

################################################################################
# Ebook
################################################################################

dlangspec.d : $(addsuffix .dd,$(SPEC_ROOT))
	$(RDMD) ../tools/catdoc.d -o$@ $^

dlangspec.html : $(DDOC) ebook.ddoc dlangspec.d $(DMD)
	$(DMD) $(DDOC) ebook.ddoc dlangspec.d

dlangspec.zip : dlangspec.html ebook.css
	rm -f $@
	zip $@ dlangspec.html ebook.css

$(DOC_OUTPUT_DIR)/dlangspec.mobi : \
		dlangspec.opf dlangspec.html dlangspec.png dlangspec.ncx ebook.css
	rm -f $@ dlangspec.mobi
# kindlegen has warnings, ignore them for now
	-kindlegen dlangspec.opf
	mv dlangspec.mobi $@

################################################################################
# LaTeX
################################################################################

dlangspec-consolidated.d : $(addsuffix .dd,$(SPEC_ROOT))
	$(RDMD) --force ../tools/catdoc.d -o$@ $^

dlangspec.tex : $(DMD) $(DDOC) latex.ddoc dlangspec-consolidated.d
	$(DMD) -Df$@ $(DDOC) latex.ddoc dlangspec-consolidated.d

# Run twice to fix multipage tables and \ref uses
dlangspec.dvi : dlangspec.tex
	latex $^
	latex $^

$(DOC_OUTPUT_DIR)/dlangspec.pdf : dlangspec.dvi
	dvipdf $^ $@

################################################################################
# Plaintext/verbatim generation - not part of the build, demo purposes only
################################################################################

dlangspec.txt : $(DMD) macros.ddoc plaintext.ddoc dlangspec-consolidated.d
	$(DMD) -Df$@ macros.ddoc plaintext.ddoc dlangspec-consolidated.d

dlangspec.verbatim.txt : $(DMD) macros.ddoc verbatim.ddoc dlangspec-consolidated.d
	$(DMD) -Df$@ macros.ddoc verbatim.ddoc dlangspec-consolidated.d

################################################################################
# Git rules
################################################################################

../%-${LATEST}/.cloned :
	[ -d $(@D) ] || git clone -b v${LATEST} --depth=1 ${GIT_HOME}/$* $(@D)/
	touch $@

../%-${DUB_VER}/.cloned :
	[ -d $(@D) ] || git clone -b v${DUB_VER} --depth=1 ${GIT_HOME}/$* $(@D)/
	touch $@

../%/.cloned :
	[ -d $(@D) ] || git clone --depth=1 ${GIT_HOME}/$* $(@D)/
	touch $@

################################################################################
# dmd compiler, latest released build and current build
################################################################################

$(DMD) : ${DMD_DIR}/.cloned
	${MAKE} --directory=${DMD_DIR}/src -f posix.mak -j 4

$(DMD_REL) : ${DMD_DIR}-${LATEST}/.cloned
	${MAKE} --directory=${DMD_DIR}-${LATEST}/src -f posix.mak -j 4

################################################################################
# druntime, latest released build and current build
################################################################################

druntime-prerelease : ${DRUNTIME_DIR}/.cloned ${DOC_OUTPUT_DIR}/phobos-prerelease/object.html
${DOC_OUTPUT_DIR}/phobos-prerelease/object.html : $(DMD)
	${MAKE} --directory=${DRUNTIME_DIR} -f posix.mak -j 4 \
		DOCDIR=${DOC_OUTPUT_DIR}/phobos-prerelease \
		DOCFMT="`pwd`/html.ddoc `pwd`/dlang.org.ddoc `pwd`/std_navbar-prerelease.ddoc `pwd`/std.ddoc `pwd`/macros.ddoc"

druntime-release : ${DRUNTIME_DIR}-${LATEST}/.cloned ${DOC_OUTPUT_DIR}/phobos/object.html
${DOC_OUTPUT_DIR}/phobos/object.html : $(DMD_REL)
	${MAKE} --directory=${DRUNTIME_DIR}-${LATEST} -f posix.mak \
	  DMD=$(DMD_REL) \
	  DOCDIR=${DOC_OUTPUT_DIR}/phobos \
	  DOCFMT="`pwd`/html.ddoc `pwd`/dlang.org.ddoc `pwd`/std_navbar-$(LATEST).ddoc `pwd`/std.ddoc `pwd`/macros.ddoc" -j 4

################################################################################
# phobos, latest released build and current build
################################################################################

phobos-prerelease : ${PHOBOS_DIR}/.cloned ${DOC_OUTPUT_DIR}/phobos-prerelease/index.html
${DOC_OUTPUT_DIR}/phobos-prerelease/index.html : html.ddoc dlang.org.ddoc std.ddoc macros.ddoc \
	    ${DOC_OUTPUT_DIR}/phobos-prerelease/object.html
	${MAKE} --directory=${PHOBOS_DIR} -f posix.mak \
	  STDDOC="`pwd`/html.ddoc `pwd`/dlang.org.ddoc `pwd`/std_navbar-prerelease.ddoc `pwd`/std.ddoc `pwd`/macros.ddoc" \
	  DOC_OUTPUT_DIR=${DOC_OUTPUT_DIR}/phobos-prerelease html -j 4

phobos-release : ${PHOBOS_DIR}-${LATEST}/.cloned ${DOC_OUTPUT_DIR}/phobos/index.html
${DOC_OUTPUT_DIR}/phobos/index.html : $(DMD_REL) html.ddoc dlang.org.ddoc std.ddoc macros.ddoc ${LATEST}.ddoc \
	    ${DOC_OUTPUT_DIR}/phobos/object.html
	${MAKE} --directory=${PHOBOS_DIR}-${LATEST} -f posix.mak -j 4 \
	  html \
	  DMD=$(DMD_REL) \
	  DRUNTIME_PATH=${DRUNTIME_DIR}-${LATEST} \
	  DOC_OUTPUT_DIR=${DOC_OUTPUT_DIR}/phobos \
	  STDDOC="`pwd`/html.ddoc `pwd`/dlang.org.ddoc `pwd`/$(LATEST).ddoc `pwd`/std_navbar-$(LATEST).ddoc `pwd`/std.ddoc `pwd`/macros.ddoc"

################################################################################
# phobos and druntime, latest released build and current build (DDOX version)
################################################################################

apidocs-prerelease : ${DOC_OUTPUT_DIR}/library-prerelease/sitemap.xml
apidocs-release : ${DOC_OUTPUT_DIR}/library/sitemap.xml
apidocs-serve : docs-prerelease.json
	${DPL_DOCS} serve-html --std-macros=html.ddoc --std-macros=dlang.org.ddoc --std-macros=std.ddoc --std-macros=macros.ddoc --std-macros=std-ddox.ddoc \
	  --override-macros=std-ddox-override.ddoc --package-order=std \
	  --git-target=master --web-file-dir=. docs-prerelease.json

${DOC_OUTPUT_DIR}/library-prerelease/sitemap.xml : docs-prerelease.json
	@mkdir -p $(dir $@)
	${DPL_DOCS} generate-html --file-name-style=lowerUnderscored --std-macros=html.ddoc --std-macros=dlang.org.ddoc --std-macros=std.ddoc --std-macros=macros.ddoc --std-macros=std-ddox.ddoc \
	  --override-macros=std-ddox-override.ddoc --package-order=std \
	  --git-target=master docs-prerelease.json ${DOC_OUTPUT_DIR}/library-prerelease

${DOC_OUTPUT_DIR}/library/sitemap.xml : docs.json
	@mkdir -p $(dir $@)
	${DPL_DOCS} generate-html --file-name-style=lowerUnderscored --std-macros=html.ddoc --std-macros=dlang.org.ddoc --std-macros=std.ddoc --std-macros=macros.ddoc --std-macros=std-ddox.ddoc \
	  --override-macros=std-ddox-override.ddoc --package-order=std \
	  --git-target=v${LATEST} docs.json ${DOC_OUTPUT_DIR}/library

docs.json : ${DMD_REL} ${DRUNTIME_DIR}-${LATEST}/.cloned \
		${PHOBOS_DIR}-${LATEST}/.cloned | dpl-docs
	find ${DRUNTIME_DIR}-${LATEST}/src -name '*.d' | \
	  sed -e /unittest.d/d -e /gcstub/d > .release-files.txt
	find ${PHOBOS_DIR}-${LATEST} -name '*.d' | \
	  sed -e /unittest.d/d -e /format/d -e /windows/d >> .release-files.txt
	${DMD_REL} -c -o- -version=CoreDdoc -version=StdDdoc -Df.release-dummy.html \
	  -Xfdocs.json -I${PHOBOS_DIR}-${LATEST} @.release-files.txt
	${DPL_DOCS} filter docs.json --min-protection=Protected --only-documented \
	  --ex=gc. --ex=rt. --ex=core.internal. --ex=std.internal.
	rm .release-files.txt .release-dummy.html

docs-prerelease.json : ${DMD} ${DRUNTIME_DIR}/.cloned \
		${PHOBOS_DIR}/.cloned | dpl-docs
	find ${DRUNTIME_DIR}/src -name '*.d' | sed -e '/gcstub/d' \
	  -e /unittest/d > .prerelease-files.txt
	find ${PHOBOS_DIR} -name '*.d' | sed -e /unittest.d/d -e /format/d \
	  -e /windows/d >> .prerelease-files.txt
	${DMD} -c -o- -version=CoreDdoc -version=StdDdoc -Df.prerelease-dummy.html \
	  -Xfdocs-prerelease.json -I${PHOBOS_DIR} @.prerelease-files.txt
	${DPL_DOCS} filter docs-prerelease.json --min-protection=Protected \
	  --only-documented --ex=gc. --ex=rt. --ex=core.internal. --ex=std.internal.
	rm .prerelease-files.txt .prerelease-dummy.html

################################################################################
# binary targets for DDOX
################################################################################

.PHONY: dpl-docs
dpl-docs: ${DUB} ${STABLE_DMD}
	${DUB} build --root=${DPL_DOCS_PATH} --compiler=${STABLE_DMD}

${STABLE_DMD}:
	mkdir -p ${STABLE_DMD_ROOT}
	TMPFILE=$$(mktemp deleteme.XXXXXXXX) && curl -fsSL ${STABLE_DMD_URL} > $${TMPFILE}.zip && \
		unzip -qd ${STABLE_DMD_ROOT} $${TMPFILE}.zip && rm $${TMPFILE}.zip

${DUB}: ${DUB_DIR}/.cloned ${STABLE_DMD}
	cd ${DUB_DIR}; DC=$(abspath ${STABLE_DMD}) ./build.sh
