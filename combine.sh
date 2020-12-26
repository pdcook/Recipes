#!/bin/bash
script_dir=$(pwd)
out_file="combined.pdf"
tmp_dir="$script_dir/.tmp"
bookmarks_file="$tmp_dir/bookmarks.txt"
bookmarks_fmt="BookmarkBegin
BookmarkTitle: %s
BookmarkLevel: 1
BookmarkPageNumber: 1
"

rm -rf "$tmp_dir"
mkdir -p "$tmp_dir"

for d in */; do
    echo "Moving to $d..."
    cd "$d"
    for f in *.pdf; do
        echo "Bookmarking $f..."
        title="${f%.*}"
        spaced_name=$(echo "$title" | sed -e 's/\([^[:blank:]]\)\([[:upper:]]\)/\1 \2/g' \
      -e 's/\([^[:blank:]]\)\([[:upper:]]\)/\1 \2/g')
        printf "$bookmarks_fmt" "$spaced_name" > "$bookmarks_file"
        pdftk "$f" update_info "$bookmarks_file" output "$tmp_dir/$f"
    done
    cd "$script_dir"
done

pdftk "$tmp_dir"/*.pdf cat output "$out_file"

