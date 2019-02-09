set -xe
# Compile site generator
stack build
# Build my site
stack exec site build

# Checkout the deploy branch
git checkout deploy

# Copy all files in _site to the root
rsync -a --filter='P _site/'      \
         --filter='P _cache/'     \
         --filter='P .git/'       \
         --filter='P .gitignore'  \
         --filter='P .stack-work' \
         --delete-excluded        \
         _site/ .

# Commit all generated files
git add -A
git commit -m 'Deploy commit'

# Push
git push origin deploy:gh-pages

# Go back to the master branch
git checkout master
