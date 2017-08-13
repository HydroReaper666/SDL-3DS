#!/bin/sh
#
# Generate dependencies from a list of source files

# Check to make sure our environment variables are set
if test x"$INCLUDE" = x -o x"$SOURCES" = x -o x"$output" = x; then
    echo "SOURCES, INCLUDE, and output needs to be set"
    exit 1
fi
cache_prefix=".#$$"

generate_var()
{
    echo $1 | sed -e 's|^.*/||' -e 's|\.|_|g'
}

search_deps()
{
    base=`echo $1 | sed 's|/[^/]*$||'`
    grep '#include "' <$1 | sed -e 's|.*"\([^"]*\)".*|\1|' | \
    while read file
    do cache=${cache_prefix}_`generate_var $file`
       if test -f $cache; then
          : # We already ahve this cached
       else
           : >$cache
           for path in $base `echo $INCLUDE | sed 's|-I||g'`
           do dep="$path/$file"
              if test -f "$dep"; then
                 echo "	$dep \\" >>$cache
                 search_deps $dep >>$cache
                 break
              fi
           done
       fi
       cat $cache
    done
}

:>${output}.new
for src in $SOURCES
do  echo "Generating dependencies for $src"
    ext=`echo $src | sed 's|.*\.\(.*\)|\1|'`
    obj=`echo $src | sed "s|^.*/\([^ ]*\)\..*|\1.lo|g"`
    if test x"$ext" != x"pica"; then
      echo "\$(objects)/$obj: $src \\" >>${output}.new
    else
      stem=`echo $src | sed "s|^.*/\([^ ]*\)\..*|\1|g"`
      obj=$stem.shbin.o
      hdr=${stem}_shbin.h
      shbin=$stem.shbin
      cat >>${output}.new <<__EOF__
\$(objects)/$stem.shbin.lo: \$(objects)/$obj
	@echo "# $stem.shbin.lo - a libtool object file" > \$@
	@echo "# Generated by ltmain.sh (GNU libtool) 2.2.6" >> \$@
	@echo "pic_object=none" >> \$@
	@echo "non_pic_object='$stem.shbin.o'" >> \$@

\$(objects)/$obj \$(objects)/$hdr: \$(objects)/$shbin
	@echo "extern const u8 ${stem}_shbin[];" > \$(objects)/$hdr
	@echo "extern const u8 ${stem}_shbin_end[];" >> \$(objects)/$hdr
	@echo "extern const u32 ${stem}_shbin_size;" >> \$(objects)/$hdr
	@bin2s \$(objects)/$shbin | arm-none-eabi-as -o \$(objects)/$obj


\$(objects)/$shbin: $src
	picasso -o \$@ \$<
__EOF__
    fi
    # No search to be done with Windows resource files
    if test x"$ext" != x"rc"; then
        search_deps $src | sort | uniq >>${output}.new
    fi
    case $ext in
        pica)
        ;;
        c) cat >>${output}.new <<__EOF__

	\$(LIBTOOL) --mode=compile \$(CC) \$(CFLAGS) \$(EXTRA_CFLAGS) -c $src  -o \$@

__EOF__
        ;;
        cc) cat >>${output}.new <<__EOF__

	\$(LIBTOOL) --mode=compile \$(CC) \$(CFLAGS) \$(EXTRA_CFLAGS) -c $src  -o \$@

__EOF__
        ;;
        m) cat >>${output}.new <<__EOF__

	\$(LIBTOOL) --mode=compile \$(CC) \$(CFLAGS) \$(EXTRA_CFLAGS) -c $src  -o \$@

__EOF__
        ;;
        asm) cat >>${output}.new <<__EOF__

	\$(LIBTOOL) --tag=CC --mode=compile \$(auxdir)/strip_fPIC.sh \$(NASM) -I\$(srcdir)/src/hermes/ $src -o \$@

__EOF__
        ;;
        S) cat >>${output}.new <<__EOF__

	\$(LIBTOOL)  --mode=compile \$(CC) \$(CFLAGS) \$(EXTRA_CFLAGS) -c $src  -o \$@

__EOF__
        ;;
        rc) cat >>${output}.new <<__EOF__

	\$(LIBTOOL)  --tag=RC --mode=compile \$(WINDRES) $src -o \$@

__EOF__
        ;;
        *)   echo "Unknown file extension: $ext";;
    esac
    echo "" >>${output}.new
done
mv ${output}.new ${output}
rm -f ${cache_prefix}*
