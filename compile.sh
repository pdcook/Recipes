#!/bin/bash
# get path to this script
SCRIPT=`realpath $0`
SCRIPTPATH=`dirname $SCRIPT`

# get terminal codes for colors, bold, and normal text
bold=$(tput bold)
normal=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 2)

# option for recompiling all recipes that have been edited
a_flag=false

# option for just directly merging all pdfs instead of generating a basic book
m_flag=false

# verbose option
verbose=false

# EXTRA verbose (FULL LaTeX output)
extra=false

# option to run slower (one process at a time)
s_flag=false

# option to supress spinner
quiet=false

# force recompilation of all recipes
force=false

# path to output file
output_file_path='Recipes.pdf'

# path to parent directory which is home to all recipe pdfs
recipes_parent_dir="$PWD"

usage="$(basename "$0") [-h] [-admoqsvx] -- combine all recipes

Note: This script assumes each recipe's file name is the name of the recipe
      written in CamelCase. For example, for a fresh strawberry oatmeal recipe,
      the filename should be something like FreshStrawberryOatmeal.tex,
      DailyOatmeal.tex, MyFavoriteWinterBreakfast.tex, etc.

where:
    -h  show this help text

    -a  recompile all recipes in parent directory that have been edited

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

    -f force compile everything, even if some recipes have not been changed

    -m  directly merge all recipe pdfs instead of generating a basic book

    -s  run slower, usually for debug purposes

    -o  path to output file [Default: Recipes.pdf]

    -q  quiet, supress all console output

    -v  verbose

    -x  EXTRA verbose (show all LaTeX compiler output"

while getopts 'asmd:o:vhxqf' flag; do
  case "${flag}" in
    a) a_flag=true ;;
    m) m_flag=true ;;
    s) s_flag=true ;;
    d) recipes_parent_dir="${OPTARG}" ;;
    o) output_file_path="${OPTARG}" ;;
    v) verbose=true ;;
    x) extra=true ;;
    h) echo "$usage"
       exit 2 ;;
    q) quiet=true
       verbose=false ;;
    f) force=true
       a_flag=true ;;
  esac
done

# a fancy spinor while things are working
spinner()
{
    local pid=$!
    local delay=0.15
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        if [ "$quiet" = false ]
        then
            printf "[%c]" "$spinstr"
        fi
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# start
# move to parent dir
cd "$recipes_parent_dir"

# if -s, preform some setup
if [ "$m_flag" = true ]
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
if [ "$m_flag" = false ]
then
    # this is a silly way of doing this, but it works
    tex_start="\\RequirePackage{recipebook}
\\usepackage{tocloft}
\\renewcommand\\numberline[1]{} % removes numbers from ToC
\\renewcommand{\contentsname}{Index}

\\begin{document}
\\maketitle
\\setlength{\\columnseprule}{0.5pt}
\\tableofcontents
\\addtocontents{toc}{\\protect\\thispagestyle{empty}}
\\pagenumbering{gobble}
\\setlength{\\columnseprule}{0pt}

\\pagenumbering{arabic}"

    tex_end="\\end{document}"

    tex_contents="$tex_start"

fi

# keep track of number of recompiled files
COMPILECOUNT=0
# keep track of number of new pdf files
PDFCOUNT=0


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


                if [ "$force" = false ]
                then
                    # check to see if the file has changed
                    # is the pdf modified date newer than the source?
                    # AND is the pdf creation date newer than the source
                    #   modification date
                    # AND does git diff show no changes to the .tex
                    # AND is the compiled Recipes.pdf newer than the .tex

                    git diff --quiet "$f"; nochanges=$? # git diff changes

                    # date the pdf was created on
                    creationdate="$(pdfinfo "${f%.*}.pdf" | \
                           grep CreationDate | sed -e "s|CreationDate:\s*||g")"

                    # convert to time since the epoch
                    creationdate="$(date --date="$creationdate" +"%s")"

                    # get the modification date of the tex file
                    modificationdate="$(date -r "$f" +"%s")"

                    echo "$creationdate"
                    echo "$modificationdate"

                    if [ "${f%.*}.pdf" -nt "$f" ] && \
                       [ "$creationdate" -ge "$modificationdate" ] && \
                       [ "$nochanges" = 0 ] && \
                       [ "$SCRIPTPATH/Recipes.pdf" -nt "$f" ]
                    then
                        if [ "$verbose" = true ]
                        then
                            echo "    $f unchanged, skipping compilation."
                        fi

                        continue

                    else
                        if [ "$verbose" = true ]
                        then
                            echo "${green}${bold}    $f changed.${normal}"
                        fi

                        # increase the changed file counter
                        COMPILECOUNT=$[COMPILECOUNT + 1]
                    fi
                else

                    # if force is set, then every file will be recompiled
                    COMPILECOUNT=$[COMPILECOUNT + 1]

                fi


                if [ "$verbose" = true ]
                then
                    echo "    Compiling $f..."
                fi

                if [ "$extra" = false ]
                then
                    if [ "$s_flag" = false ]
                    then
                        {
                        pdflatex "$f" > /dev/null 2>&1
                        pdflatex "$f" > /dev/null 2>&1
                        } &
                    fi

                    if [ "$s_flag" = true ]
                    then
                        pdflatex "$f" > /dev/null 2>&1 &
                        spinner
                        pdflatex "$f" > /dev/null 2>&1 &
                        spinner
                    fi
                fi

                if [ "$extra" = true ]
                then
                    if [ "$s_flag" = false ]
                    then
                        {
                        pdflatex "$f"
                        pdflatex "$f"
                        } &
                    fi

                    if [ "$s_flag" = true ]
                    then
                        pdflatex "$f" &
                        spinner
                        pdflatex "$f" &
                        spinner
                    fi
                fi

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
        if [ "$m_flag" = true ]
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
        if [ "$m_flag" = false ]
        then
            if [ "$verbose" = true ]
            then
                echo "        Writing TeX entry..."
            fi
            tex_contents="$tex_contents
\includepdf[pagecommand={\\thispagestyle{fancy}},linktodoc=true,pages=-,addtotoc={1,section,1, $spaced_name, \
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

# spin while individual recipes may still be compiling
if [ "$a_flag" = true ] && [ "$COMPILECOUNT" -gt 0 ]
then
    spinner
fi

if [ "$verbose" = true ]
then
    echo "Done."
fi

# check to see how many pdfs may have changed after possible compilation
for recipe_dir in */; do

    # move to recipe folder
    cd "$recipe_dir"

    for f in *.pdf; do

        if [ "$force" = false ]
        then
            # check to see if the file has changed
            git diff --quiet "$f"; nochanges=$?
            if [ "$nochanges" = 0 ] && \
               [ "$SCRIPTPATH/Recipes.pdf" -nt "$f" ]
            then
                if [ "$verbose" = true ]
                then
                    echo "$f unchanged."
                fi

            else

                if [ "$verbose" = true ]
                then
                    echo "${green}${bold}$f changed.${normal}"
                fi

                # increase the changed file counter
                PDFCOUNT=$[PDFCOUNT + 1]
            fi
        else

            # if force is set, then every file will be recompiled
            PDFCOUNT=$[PDFCOUNT + 1]

        fi

        # move back to parent dir
        cd "$recipes_parent_dir"
    done
done

# if -s output the merged pdf and exit 0
if [ "$m_flag" = true ]
then
    if [ "$verbose" = true ]
    then
        echo "Writing $output_file_path..."
    fi

    pdftk "$tmp_dir"/*.pdf cat output "$output_file_path" &
    spinner

    if [ "$verbose" = true ]
    then
        echo "Done."
    fi

    rm -rf "$tmp_dir"

    exit 0
fi

# if not -s compile the recipe book
if [ "$m_flag" = false ]
then

    echo "$COMPILECOUNT"
    echo "$PDFCOUNT"

    if [ "$COMPILECOUNT" = 0 ]
    then

        if [ "$quiet" = false ]
        then
            echo "${red}No recipes have changed, so no compilation was attempted.${normal}"
        fi
    fi

    if [ "$PDFCOUNT" = 0 ]
    then

        if [ "$quiet" = false ]
        then
            echo "${red}${bold}No recipe PDFs have changed, so no output was attempted.${normal}"
        fi

        touch "${output_file_path%.*}.tex"
        touch "${output_file_path%.*}.pdf"

        exit 1
    fi


    if [ "$verbose" = true ]
    then
        echo "Writing $output_file_path..."
    fi

    tex_contents="$tex_contents
$tex_end"

    echo "$tex_contents" > "${output_file_path%.*}.tex"

    if [ "$extra" = false ]
    then
        {
        pdflatex "${output_file_path%.*}.tex" > /dev/null 2>&1
        pdflatex "${output_file_path%.*}.tex" > /dev/null 2>&1
        } &
        spinner
    fi

    if [ "$extra" = true ]
    then
        {
        pdflatex "${output_file_path%.*}.tex"
        pdflatex "${output_file_path%.*}.tex"
        } &
        spinner
    fi

    if [ "$verbose" = true ]
    then
        echo "Done."
    fi

    exit 0
fi
