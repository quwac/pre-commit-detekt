#!/bin/sh

set -u

ends_with() {
    target="${1}"
    suffix="${2}"

    case $target in
    *$suffix)
        echo 0
        ;;
    *)
        echo 1
        ;;
    esac
}

current_dir=$(pwd)
repo_dir=$(
    cd "$(dirname "$0")" || exit 1
    pwd
)
cd "$current_dir" >/dev/null || exit 1

# Parse arguments for entrypoint.sh
if [ "$1" = "container" ]; then
    detekt_version="$(cat /opt/detekt/version)"
elif [ "$1" = "host" ]; then
    detekt_version="$(cat "$repo_dir/version")"
else
    echo "Usage: $0 [container|host] [options] [filenames]"
    exit 2
fi
detekt_version="$(echo "$detekt_version" | sed -e 's/^v//g')"

detekt_jar_name="detekt-cli-$detekt_version-all.jar"
if [ "$1" = "container" ]; then
    detekt_jar_path="/opt/detekt/$detekt_jar_name"
    base_path="/src"
elif [ "$1" = "host" ]; then
    detekt_jar_path="$repo_dir/$detekt_jar_name"
    base_path="$current_dir"
fi
shift 1

set +u
if [ -n "$JAVA_HOME" ]; then
    if [ -x "$JAVA_HOME/jre/sh/java" ]; then
        # IBM's JDK on AIX uses strange locations for the executables
        javacmd=$JAVA_HOME/jre/sh/java
    else
        javacmd=$JAVA_HOME/bin/java
    fi
    if [ ! -x "$javacmd" ]; then
        die "ERROR: JAVA_HOME is set to an invalid directory: $JAVA_HOME

Please set the JAVA_HOME variable in your environment to match the
location of your Java installation."
    fi
else
    javacmd=java
    which java >/dev/null 2>&1 || die "ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH.

Please set the JAVA_HOME variable in your environment to match the
location of your Java installation."
fi
set -u

# Parse arguments for detekt
opts=""
filenames=""
filenames_started=0
input_included=0
base_path_included=0
for i in "$@"; do
    if [ "$i" = "--input" ] || [ "$i" = "-i" ]; then
        input_included=1
    fi
    if [ "$i" = "--base-path" ] || [ "$i" = "-bp" ]; then
        base_path_included=1
    fi

    if [ $filenames_started -eq 0 ]; then
        if [ "$(ends_with "$i" ".kt")" -eq 0 ] || [ "$(ends_with "$i" ".kts")" -eq 0 ]; then
            filenames_started=1
        fi
    fi

    if [ $filenames_started -eq 1 ]; then
        if [ "$filenames" != "" ]; then
            filenames="$filenames,"
        fi
        filenames="${filenames}${i}"
    else
        if [ "$opts" != "" ]; then
            opts="$opts "
        fi
        opts="$opts$i"
    fi
done

if [ $base_path_included -eq 0 ]; then
    if [ "$opts" != "" ]; then
        opts="$opts "
    fi
    opts="${opts}--base-path $base_path"
fi

cd "$base_path" >/dev/null || exit 1

# Download detekt if it doesn't exist
if [ ! -f "$detekt_jar_path" ]; then
    detekt_dir=$(
        cd "$(dirname "$detekt_jar_path")" || exit 1
        pwd
    )
    cd "$detekt_dir" >/dev/null || exit 1

    echo "Downloading detekt..."
    remote_detekt_url="https://github.com/detekt/detekt/releases/download/v$detekt_version/$detekt_jar_name"
    curl -sSLO "$remote_detekt_url"
    cd "$base_path" >/dev/null || exit 1
fi

# Run detekt
jvm_opts="--add-opens java.base/java.lang=ALL-UNNAMED"
if [ "$filenames" = "" ] || [ $input_included -eq 1 ]; then
    # shellcheck disable=SC2086
    OUTPUT=$("$javacmd" $jvm_opts -jar "$detekt_jar_path" $opts 2>&1)
else
    # shellcheck disable=SC2086
    OUTPUT=$("$javacmd" $jvm_opts -jar "$detekt_jar_path" $opts --input "$filenames" 2>&1)
fi

EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
    echo "$OUTPUT" | sed -e 's|^/src|.|g'
    echo "***********************************************"
    echo "                 Detekt failed                 "
    echo " Please fix the above issues before committing "
    echo "***********************************************"
    exit $EXIT_CODE
fi
cd "$current_dir" >/dev/null || exit 1
