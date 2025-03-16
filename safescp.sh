#!/bin/bash

#""""""""""""""""""""""""""""""""""""""""""""""""""""""
# CONFIG
DEST="/DEST/DIR"

REMOTE_USER="remotescpuser" # example : testuser
REMOTE_HOST="remotehost"    # example IPv4: 10.1.0.2
REMOTE_PATH="/SRC/DIR"

SCP_PROCCES=5
LOCKDIR="/tmp/scp_lock"
#""""""""""""""""""""""""""""""""""""""""""""""""""""""

export DEST REMOTE_USER REMOTE_HOST REMOTE_PATH LOCKDIR

# リモートのファイルリストを取得
ssh "${REMOTE_USER}@${REMOTE_HOST}" "find '${REMOTE_PATH}' -type f | sed 's|^${REMOTE_PATH}/||' | sort" > remote_files

# ローカルのファイルリストを取得
find "${DEST}" -type f | sed "s|^$DEST/||" | sort > local_files

# 差分を取得
comm -23 remote_files local_files > diff_files

# 並列実行用のロックディレクトリ
mkdir -p "${LOCKDIR}"

# 並列でファイルをコピー
cat diff_files | xargs -P $SCP_PROCCES -I {} bash -c '
    FILE="{}"
    LOCKFILE="$LOCKDIR/$(echo "$FILE" | tr "/" "_").lock"

    exec 200>"$LOCKFILE"
    if flock -n 200; then
        mkdir -p "$(dirname "$DEST/$FILE")"
        if ! [ -f "$DEST/$FILE" ]; then
            scp -q -c aes128-gcm@openssh.com "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/$FILE" "$DEST/$FILE" && rm -f "$LOCKFILE"
        fi
    fi
'

