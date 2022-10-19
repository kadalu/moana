browser:
	mkdir -p dist
	esbuild --bundle main_browser.js --outfile=./dist/kadalu-storage-min.js --minify

browser-no-minify:
	mkdir -p dist
	esbuild --bundle main_browser.js --outfile=./dist/kadalu-storage.js

node:
	esbuild main_node.js --bundle --platform=node --outfile=output_node.js
