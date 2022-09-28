browser:
	mkdir -p dist
	esbuild --bundle main_browser.js --outfile=./dist/kadalu-storage-min.js --minify

node:
	esbuild main_node.js --bundle --platform=node --outfile=output_node.js
