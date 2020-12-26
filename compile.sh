#!/bin/bash
# option for recompiling all recipes
a_flag=false

# option for just directly merging all pdfs instead of generating a basic book
s_flag=false

# verbose option
verbose=false

# path to output file
output_file_path='Recipes.pdf'

# path to parent directory which is home to all recipe pdfs
recipes_parent_dir="$PWD"

usage="$(basename "$0") [-h] [-adsov] -- combine all recipes

Note: This script assumes each recipe's file name is the name of the recipe
      written in CamelCase. For example, for a fresh strawberry oatmeal recipe,
      the filename should be something like FreshStrawberryOatmeal.tex,
      DailyOatmeal.tex, MyFavoriteWinterBreakfast.tex, etc.

where:
    -h  show this help text

    -a  recompile all recipes in parent directory

    -d  path to parent directory containing all recipe directories [Default: .]
            Expected file structure:
           |/path/to/parent/dir/
           |                   |
           |                   |RecipeOne/
           |                   |       |RecipeOne.tex
           |                   |       |RecipeOne.pdf
           |                   |RecipeTwo/
           |                   |       |RecipeTwo.tex
           |                   |       |RecipeTwo.pdf
           |                   |RecipeThree/
           |                   |       |RecipeThree.tex
           |                   |       |RecipeThree.pdf
           |                   |...
           |                   |...
           |                   |...

    -s  directly merge all recipe pdfs instead of generating a basic book

    -o  path to output file [Default: Recipes.pdf]

    -v  verbose"


while getopts 'asd:o:vh' flag; do
  case "${flag}" in
    a) a_flag=true ;;
    s) s_flag=true ;;
    d) recipes_parent_dir="${OPTARG}" ;;
    o) output_file_path="${OPTARG}" ;;
    v) verbose=true ;;
    h) echo "$usage"
       exit 0 ;;
  esac
done

# start

# move to parent dir
cd "$recipes_parent_dir"

# if -s, preform some setup
if [ "$s_flag" = true ]
then
    tmp_dir="$recipes_parent_dir/.tmp"
    bookmarks_file="$tmp_dir/bookmarks.txt"
    bookmarks_fmt="BookmarkBegin
BookmarkTitle: %s
BookmarkLevel: 1
BookmarkPageNumber: 1
"

    rm -rf "$tmp_dir"
    mkdir -p "$tmp_dir"
fi

# if not -s, preform different setup
if [ "$s_flag" = false ]
then
    # this is a silly way of doing this, but it works
    tex_start="\\RequirePackage{recipebook}
    \\usepackage{tocloft}
    \\renewcommand\\numberline[1]{} % removes numbers from ToC

    \\begin{document}
    \\maketitle
    \\setlength{\\columnseprule}{0.5pt}
    \\tableofcontents
    \\addtocontents{toc}{\\protect\\thispagestyle{empty}}
    \\pagenumbering{gobble}
    \\setlength{\\columnseprule}{0pt}

    \\pagenumbering{arabic}

    \\begin{samepage}"

    tex_end="\\end{samepage}

    \\end{document}"

    tex_contents="$tex_start"

fi


# loop through all subdirectories for recipes
for recipe_dir in */; do
    if [ "$verbose" = true ]
    then
        echo "$recipe_dir"
    fi

    # move to recipe dir
    cd "$recipe_dir"

    # if -a, then recompile all tex files in each recipe
    if [ "$a_flag" = true ]
    then
        for f in *.tex; do

                if [ "$verbose" = true ]
                then
                    echo "    Compiling $f..."
                fi

                pdflatex "$f" > /dev/null 2>&1
                pdflatex "$f" > /dev/null 2>&1

        done
    fi

    # loop through all pdf files in recipe dir
    for f in *.pdf; do
        title="${f%.*}"
        spaced_name=$(echo "$title" | \
                    sed -e 's/\([^[:blank:]]\)\([[:upper:]]\)/\1 \2/g' \
                        -e 's/\([^[:blank:]]\)\([[:upper:]]\)/\1 \2/g')

        if [ "$verbose" = true ]
        then
            echo "    $spaced_name"
        fi

        # if -s, then just merge the pdfs and be done
        if [ "$s_flag" = true ]
        then

            # make bookmarks for pdfs and prepare them for merge
            if [ "$verbose" = true ]
            then
                echo "        Bookmarking $spaced_name..."
            fi

            printf "$bookmarks_fmt" "$spaced_name" > "$bookmarks_file"
            pdftk "$f" update_info "$bookmarks_file" output "$tmp_dir/$f"

            if [ "$verbose" = true ]
            then
                echo "        Done."
            fi
            cd "$script_dir"

        fi

        # if not -s, then create the basic recipe book (in a very dumb way)
        if [ "$s_flag" = false ]
        then
            if [ "$verbose" = true ]
            then
                echo "        Writing TeX entry..."
            fi
            tex_contents="$tex_contents
\includepdf[linktodoc=true,pages=-,addtotoc={1,section,1, $spaced_name, \
sec:$title}]{$recipe_dir/$f}"
            if [ "$verbose" = true ]
            then
                echo "        Done."
            fi
        fi

    done

    # move back to parent dir
    cd "$recipes_parent_dir"
done

# if -s output the merged pdf and exit 0
if [ "$s_flag" = true ]
then
    if [ "$verbose" = true ]
    then
        echo "Writing $output_file_path"
    fi

    pdftk "$tmp_dir"/*.pdf cat output "$output_file_path"

    if [ "$verbose" = true ]
    then
        echo "Done."
    fi

    rm -rf "$tmp_dir"

    exit 0
fi

# if not -s compile the recipe book
if [ "$s_flag" = false ]
then
    if [ "$verbose" = true ]
    then
        echo "Writing $output_file_path"
    fi

    tex_contents="$tex_contents
$tex_end"


    echo "$tex_contents" > "${output_file_path%.*}.tex"

    pdflatex "${output_file_path%.*}.tex"
    pdflatex "${output_file_path%.*}.tex"

    if [ "$verbose" = true ]
    then
        echo "Done."
    fi

    exit 0
fi
