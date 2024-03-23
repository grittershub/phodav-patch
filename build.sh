#!/bin/sh -x 

fixup () {
    FILE=$1
    BASE=$(basename "$FILE")
    BASEFILENAME=${BASE%.*}
    LIBNAME=${BASEFILENAME#lib*}
    BUNDLE_ID="com.utmapp.${LIBNAME//_/-}"
    FRAMEWORKNAME="$LIBNAME.framework"
    BASEFRAMEWORKPATH="$PREFIX/Frameworks/$FRAMEWORKNAME"
    if [ "$PLATFORM" == "macos" ]; then
        FRAMEWORKPATH="$BASEFRAMEWORKPATH/Versions/A"
        INFOPATH="$FRAMEWORKPATH/Resources"
    else
        FRAMEWORKPATH="$BASEFRAMEWORKPATH"
        INFOPATH="$FRAMEWORKPATH"
    fi
    NEWFILE="$FRAMEWORKPATH/$LIBNAME"
    LIST=$(otool -L "$FILE" | tail -n +2 | cut -d ' ' -f 1 | awk '{$1=$1};1')
    OLDIFS=$IFS
    IFS=$'\n'
    echo "${GREEN}Fixing up $FILE...${NC}"
    mkdir -p "$FRAMEWORKPATH"
    mkdir -p "$INFOPATH"
    cp -a "$FILE" "$NEWFILE"
    /usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $LIBNAME" "$INFOPATH/Info.plist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$INFOPATH/Info.plist"
    /usr/libexec/PlistBuddy -c "Add :MinimumOSVersion string $SDKMINVER" "$INFOPATH/Info.plist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1" "$INFOPATH/Info.plist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 1.0" "$INFOPATH/Info.plist"
    if [ "$PLATFORM" == "macos" ]; then
        ln -sf "A" "$BASEFRAMEWORKPATH/Versions/Current"
        ln -sf "Versions/Current/Resources" "$BASEFRAMEWORKPATH/Resources"
        ln -sf "Versions/Current/$LIBNAME" "$BASEFRAMEWORKPATH/$LIBNAME"
    fi
    newname="@rpath/$FRAMEWORKNAME/$LIBNAME"
    install_name_tool -id "$newname" "$NEWFILE"
    for g in $LIST
    do
        base=$(basename "$g")
        basefilename=${base%.*}
        libname=${basefilename#lib*}
        dir=$(dirname "$g")
        if [ "$dir" == "$PREFIX/lib" ]; then
            if [ "$PLATFORM" == "macos" ]; then
                newname="@rpath/$libname.framework/Versions/A/$libname"
            else
                newname="@rpath/$libname.framework/$libname"
            fi
            install_name_tool -change "$g" "$newname" "$NEWFILE"
        fi
    done
    IFS=$OLDIFS
}

cd phodav-2.5
PREFIX=/Users/nigel/phodav-build/output
meson utm_build --prefix=$PREFIX --buildtype=plain --cross-file /Users/nigel/phodav-build/meson.cross
meson compile -C utm_build -j 12
meson install -C utm_build
cd ..
fixup output/lib/libphodav-2.0.0.dylib
