rm build/*
rake
coffee -b -c -o build ./build/morphee-coffee.coffee 
cp src/morphee-coffee.html build
cp src/morphee-coffee-test-launcher.html build
