#######################################################################
#  v      #   The Coq Proof Assistant  /  The Coq Development Team    #
# <O___,, #        INRIA-Rocquencourt  &  LRI-CNRS-osay              #
#   \VV/  #############################################################
#    //   #      This file is distributed under the terms of the      #
#         #       GNU Lesser General Public License Version 2.1       #
#######################################################################

# $Id$ 


# Makefile for Coq
#
# To be used with GNU Make.
#
# This is the only Makefile. You won't find Makefiles in sub-directories
# and this is done on purpose. If you are not yet convinced of the advantages
# of a single Makefile, please read
#    http://miller.emu.id.au/pmiller/books/rmch/
# before complaining.
# 
# When you are working in a subdir, you can compile without moving to the
# upper directory using "make -C ..", and the output is still understood
# by Emacs' next-error.
###########################################################################


# Specific command-line options to this Makefile
#
# make GOTO_STAGE=N        # perform only stage N (with N=1,2)
# make VERBOSE=1           # restore the raw echoing of commands
# make NO_RECALC_DEPS=1    # avoid recomputing dependencies
# make NO_RECOMPILE_LIB=1  # a coqtop rebuild does not trigger a stdlib rebuild
#
# Nota: the 1 above can be replaced by any non-empty value
# More details in dev/doc/build-system*.txt


# FAQ: special features used in this Makefile
#
# * Order-only dependencies: |
#
# Dependencies placed after a bar (|) should be built before
# the current rule, but having one of them is out-of-date do not
# trigger a rebuild of the current rule.
# See http://www.gnu.org/software/make/manual/make.html#Prerequisite-Types
#
# * Annotation before commands: +/-/@
#
# a command starting by - is always successful (errors are ignored)
# a command starting by + is runned even if option -n is given to make
# a command starting by @ is not echoed before being runned
#
# * Custom functions
#
# Definition via "define foo" followed by commands (arg is $(1) etc)
# Call via "$(call foo,arg1)"
#
# * Useful builtin functions
#
# $(subst ...), $(patsubst ...), $(shell ...), $(foreach ...)
#
# * Behavior of -include
#
# If the file given to -include doesn't exist, make tries to build it,
# but doesn't care if this build fails. This can be quite surprising,
# see in particular the -include in Makefile.stage*

###########################################################################
# File lists
###########################################################################

# !! Before using FIND_VCS_CLAUSE, please read how you should in the !!
# !! FIND_VCS_CLAUSE section of dev/doc/build-system.dev.txt         !!
export FIND_VCS_CLAUSE:='(' \
  -name '{arch}' -o \
  -name '.svn' -o \
  -name '_darcs' -o \
  -name '.git' -o \
  -name '.bzr' -o \
  -name 'debian' -o \
  -name "$${GIT_DIR}" -o \
  -name '_build' \
')' -prune -o

define find
 $(shell find . $(FIND_VCS_CLAUSE) '(' -name $(1) ')' -print | sed 's|^\./||')
endef

## Files in the source tree

export YACCFILES:=$(call find, '*.mly')
export LEXFILES := $(call find, '*.mll')
export MLLIBFILES := $(call find, '*.mllib')
export ML4FILES := $(call find, '*.ml4')
export CFILES := $(call find, '*.c')

# NB: The lists of currently existing .ml and .mli files will change
# before and after a build or a make clean. Hence we do not export
# these variables, but cleaned-up versions (see below MLFILES and co)

EXISTINGML := $(call find, '*.ml')
EXISTINGMLI := $(call find, '*.mli')

## Files that will be generated

export GENMLFILES:=$(LEXFILES:.mll=.ml) $(YACCFILES:.mly=.ml) \
  scripts/tolink.ml kernel/copcodes.ml
export GENMLIFILES:=$(YACCFILES:.mly=.mli)
export GENHFILES:=kernel/byterun/coq_jumptbl.h
export GENVFILES:=theories/Numbers/Natural/BigN/NMake_gen.v
export GENPLUGINSMOD:=$(filter plugins/%,$(MLLIBFILES:%.mllib=%_mod.ml))
export GENML4FILES:= $(ML4FILES:.ml4=.ml)
export GENFILES:=$(GENMLFILES) $(GENMLIFILES) $(GENHFILES) $(GENVFILES) $(GENPLUGINSMOD)

# NB: all files in $(GENFILES) can be created initially, while
# .ml files in $(GENML4FILES) might need some intermediate building.
# That's why we keep $(GENML4FILES) out of $(GENFILES)

## More complex file lists

define diff
 $(foreach f, $(1), $(if $(filter $(f),$(2)),,$f))
endef

export MLSTATICFILES := \
 $(call diff, $(EXISTINGML), $(GENMLFILES) $(GENML4FILES) $(GENPLUGINSMOD))
export MLFILES := \
 $(sort $(EXISTINGML) $(GENMLFILES) $(GENML4FILES) $(GENPLUGINSMOD))
export MLIFILES := $(sort $(GENMLIFILES) $(EXISTINGMLI))
export MLWITHOUTMLI := $(call diff, $(MLFILES), $(MLIFILES:.mli=.ml))

include Makefile.common

###########################################################################
# Starting rules
###########################################################################

NOARG: world

.PHONY: NOARG help always tags otags

always: ;

help:
	@echo "Please use either"
	@echo "   ./configure"
	@echo "   make world"
	@echo "   make install"
	@echo "   make clean"
	@echo "or make archclean"
	@echo
	@echo "For make to be verbose, add VERBOSE=1"

# Nota: do not use the name $(MAKEFLAGS), it has a particular behavior
MAKEFLGS:=--warn-undefined-variable --no-builtin-rules

ifdef COQ_CONFIGURED
define stage-template
	@echo '*****************************************************'
	@echo '*****************************************************'
	@echo '****************** Entering stage$(1) ******************'
	@echo '*****************************************************'
	@echo '*****************************************************'
	+$(MAKE) $(MAKEFLGS) -f Makefile.stage$(1) "$@"
endef
else
define stage-template
	@echo "Please run ./configure first" >&2; exit 1
endef
endif

UNSAVED_FILES:=$(shell find . -name '.\#*v' -o -name '.\#*.ml' -o -name '.\#*.mli' -o -name '.\#*.ml4')
ifdef UNSAVED_FILES
$(error You have unsaved changes in your editor (emacs?) [$(UNSAVED_FILES)]; cancel them or save before proceeding. \
Or your editor crashed. Then, you may want to consider whether you want to restore the autosaves)
#If you try to simply remove this explicit test, the compilation may
#fail later. In particular, if a .#*.v file exists, coqdep fails to
#run.
endif

ifdef GOTO_STAGE
config/Makefile Makefile.common Makefile.build Makefile: ;

%: always
	$(call stage-template,$(GOTO_STAGE))
else

.PHONY: stage1 stage2 world revision

stage1 $(STAGE1_TARGETS) : always
	$(call stage-template,1)

stage2 $(STAGE2_TARGETS) : stage1
	$(call stage-template,2)

# Nota:
# - world is one of the targets in $(STAGE2_TARGETS), hence launching
# "make" or "make world" leads to recursion into stage1 then stage2
# - the aim of stage1 is to build grammar.cma and q_constr.cmo
# More details in dev/doc/build-system*.txt


# This is to remove the built-in rule "%: %.o" :
%: %.o
# Otherwise, "make foo" recurses into stage1, trying to build foo.o .

endif #GOTO_STAGE

###########################################################################
# Cleaning
###########################################################################

.PHONY: clean cleankeepvo objclean cruftclean indepclean doclean archclean optclean clean-ide ml4clean ml4depclean depclean cleanconfig distclean voclean devdocclean

clean: objclean cruftclean depclean docclean devdocclean

cleankeepvo: indepclean clean-ide optclean cruftclean depclean docclean devdocclean

objclean: archclean indepclean

cruftclean: ml4clean
	find . -name '*~' -o -name '*.annot' | xargs rm -f
	rm -f gmon.out core

indepclean:
	rm -f $(GENFILES)
	rm -f $(COQTOPBYTE) $(COQMKTOPBYTE) $(COQCBYTE) $(CHICKENBYTE)
	find . -name '*~' -o -name '*.cm[ioa]' | xargs rm -f
	rm -f */*.pp[iox] plugins/*/*.pp[iox]
	rm -rf $(SOURCEDOCDIR)
	rm -f toplevel/mltop.byteml toplevel/mltop.optml
	rm -f test-suite/check.log
	rm -f glob.dump
	rm -f config/revision.ml revision

docclean:
	rm -f doc/*/*.dvi doc/*/*.aux doc/*/*.log doc/*/*.bbl doc/*/*.blg doc/*/*.toc \
	doc/*/*.idx doc/*/*~ doc/*/*.ilg doc/*/*.ind doc/*/*.dvi.gz doc/*/*.ps.gz doc/*/*.pdf.gz\
	doc/*/*.???idx doc/*/*.???ind doc/*/*.v.tex doc/*/*.atoc doc/*/*.lof\
	doc/*/*.hatoc doc/*/*.haux doc/*/*.hcomind doc/*/*.herrind doc/*/*.hidx doc/*/*.hind \
	doc/*/*.htacind doc/*/*.htoc doc/*/*.v.html
	rm -f doc/stdlib/index-list.html doc/stdlib/index-body.html \
	  doc/stdlib/Library.coqdoc.tex doc/stdlib/library.files \
	  doc/stdlib/library.files.ls
	rm -f doc/*/*.ps doc/*/*.pdf 
	rm -rf doc/refman/html doc/stdlib/html doc/faq/html doc/tutorial/tutorial.v.html
	rm -f doc/stdlib/html/*.html
	rm -f doc/refman/euclid.ml doc/refman/euclid.mli
	rm -f doc/refman/heapsort.ml doc/refman/heapsort.mli
	rm -f doc/common/version.tex
	rm -f doc/refman/*.eps doc/refman/Reference-Manual.html
	rm -f doc/coq.tex

archclean: clean-ide optclean voclean
	rm -rf _build myocamlbuild_config.ml

optclean:
	rm -f $(COQTOPEXE) $(COQMKTOP) $(COQC) $(CHICKEN) $(COQDEPBOOT)
	rm -f $(COQTOPOPT) $(COQMKTOPOPT) $(COQCOPT) $(CHICKENOPT)
	rm -f $(TOOLS) $(CSDPCERT)
	find . -name '*.cmx' -o -name '*.cmxs' -o -name '*.cmxa' -o -name '*.[soa]' -o -name '*.so' | xargs rm -f

clean-ide:
	rm -f $(COQIDECMO) $(COQIDECMX) $(COQIDECMO:.cmo=.cmi) $(COQIDEBYTE) $(COQIDEOPT) $(COQIDE)
	rm -f ide/input_method_lexer.ml
	rm -f ide/highlight.ml ide/config_lexer.ml ide/config_parser.mli ide/config_parser.ml
	rm -f ide/utf8_convert.ml

ml4clean:
	rm -f $(GENML4FILES)

ml4depclean:
	find . -name '*.ml4.d' | xargs rm -f

depclean:
	find . $(FIND_VCS_CLAUSE) '(' -name '*.d' ')' -print | xargs rm -f

cleanconfig:
	rm -f config/Makefile config/coq_config.ml dev/ocamldebug-v7 ide/undo.mli

distclean: clean cleanconfig

voclean:
	rm -f states/*.coq
	find theories plugins test-suite -name '*.vo' -o -name '*.glob' | xargs rm -f

devdocclean:
	find . -name '*.dep.ps' -o -name '*.dot' | xargs rm -f

###########################################################################
# Emacs tags
###########################################################################

tags:
	echo $(MLIFILES) $(MLSTATICFILES) $(ML4FILES) | sort -r | xargs \
	etags --language=none\
	      "--regex=/let[ \t]+\([^ \t]+\)/\1/" \
	      "--regex=/let[ \t]+rec[ \t]+\([^ \t]+\)/\1/" \
	      "--regex=/and[ \t]+\([^ \t]+\)/\1/" \
	      "--regex=/type[ \t]+\([^ \t]+\)/\1/" \
              "--regex=/exception[ \t]+\([^ \t]+\)/\1/" \
	      "--regex=/val[ \t]+\([^ \t]+\)/\1/" \
	      "--regex=/module[ \t]+\([^ \t]+\)/\1/"
	echo $(ML4FILES) | sort -r | xargs \
	etags --append --language=none\
	      "--regex=/[ \t]*\([^: \t]+\)[ \t]*:/\1/"


otags: 
	echo $(MLIFILES) $(MLSTATICFILES) | sort -r | xargs otags
	echo $(ML4FILES) | sort -r | xargs \
	etags --append --language=none\
	      "--regex=/let[ \t]+\([^ \t]+\)/\1/" \
	      "--regex=/let[ \t]+rec[ \t]+\([^ \t]+\)/\1/" \
	      "--regex=/and[ \t]+\([^ \t]+\)/\1/" \
	      "--regex=/type[ \t]+\([^ \t]+\)/\1/" \
              "--regex=/exception[ \t]+\([^ \t]+\)/\1/" \
	      "--regex=/val[ \t]+\([^ \t]+\)/\1/" \
	      "--regex=/module[ \t]+\([^ \t]+\)/\1/"


%.elc: %.el
ifdef COQ_CONFIGURED
	echo "(setq load-path (cons \".\" load-path))" > $*.compile
	echo "(byte-compile-file \"$<\")" >> $*.compile
	- $(EMACS) -batch -l $*.compile
	rm -f $*.compile
else
	@echo "Please run ./configure first" >&2; exit 1
endif
