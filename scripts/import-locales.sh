#! /usr/bin/env bash

if [ ! -d Client.xcodeproj ]; then
    echo "Please run this from the project root that contains Client.xcodeproj"
    exit 1
fi

# Using svn export to get a version of the Git repo so we can use --force
# to make rerunning easy and it also allows us to ensure that the repo
# doesn't get treated as a submodule by Git
echo "Creating firefox-ios-l10n Git repo"
svn export --force https://github.com/mozilla-l10n/firefoxios-l10n/trunk firefox-ios-l10n || exit 1

# Store current relative path to the script
script_path=$(dirname "$0")

if [ "$1" == "--release" ]
then
    # Get the list of shipping locales. File is in the root of the main
    # firefox-ios code repository
    shipping_locales=$(cat shipping_locales.txt)

    # Get the list of folders within the Git l10n clone and remove those
    # not available in shipping locales.
    for folder in firefox-ios-l10n/*/
    do
        shipping_locale=false
        for locale in ${shipping_locales}
        do
            if [[ "firefox-ios-l10n/${locale}/" == ${folder} ]]
            then
                # This is a shipping locale, I can stop searching
                shipping_locale=true
                break
            fi
        done

        if ! ${shipping_locale}
        then
            # Locale is not in shipping_locales.txt
            echo "Removing non shipping locale: ${folder}"
            rm -rf "${folder}"
        fi
    done
fi

# Clean up files (remove unwanted sections, map sv-SE to sv)
${script_path}/update-xliff.py firefox-ios-l10n || exit 1

# Remove unwanted sections like Info.plist files and $(VARIABLES)
${script_path}/xliff-cleanup.py firefox-ios-l10n/*/*.xliff || exit 1

# Export XLIFF files to individual .strings files
rm -rf localized-strings || exit 1
mkdir localized-strings || exit 1
${script_path}/xliff-to-strings.py firefox-ios-l10n localized-strings|| exit 1

# Modify the Xcode project to reference the strings files we just created
${script_path}/strings-import.py Client.xcodeproj localized-strings || exit 1
