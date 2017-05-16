
import sys.io.File;

import format.gz.Reader;

typedef AssetDesc = {
	@:optional var path : String;
	@:optional var content_offset : Int;
	@:optional var size : Int;
};

class UnityUnpack
{
	static var paxheader = ~/PaxHeader/i;

	static var asset_content = ~/\/asset$/i;
	static var asset_path = ~/\/pathname$/i;

	static function main()
	{
		var args = Sys.args();

		if (args.length <= 0) {
			Sys.println("Unity package unpacker\n");
			Sys.println("Usage:\n    unityunpack <.unitypackage> [<output_directory>]\n");
			return;
		}

		var input = new haxe.io.Path(args[0]);
		var output = './${input.file}';

		if (args.length >= 2) {
			output = args[1];
		}

		var inp = File.read(input.toString(), true);
		var ungz = new format.gz.Reader(inp);

		var decompressed = new haxe.io.BytesOutput();
		ungz.readHeader();
		ungz.readData(decompressed);

		inp.close();

		trace("Decompressed");

		var tarinput = new haxe.io.BytesInput(decompressed.getBytes());
		var tar = new format.tar.Reader(tarinput);

		var assets : Map< String, AssetDesc > = new Map();

		while (true) {
			var e = tar.readEntryHeader();
			if( e == null ) break;

			var size = e.fileSize;
			var fname = e.fileName;

			var asset_name = ~/([0-9a-f]+)/i;

			if (!paxheader.match(fname) && asset_name.match(fname)) { 
				var assetName = asset_name.matched(1);

				// Remeber content position
				var a = assets.get(assetName);
				if (a == null) { a = { }; assets.set(assetName, a); }

				if (asset_content.match(fname)) {
					a.content_offset = tarinput.position;
					a.size = e.fileSize;
				} else if (asset_path.match(fname)) {
					var pos = tarinput.position;
					var path = tarinput.readString(size);

					if (path.indexOf('\n') >= 0) {
						path = path.split('\n')[0];
					}

					a.path = path;
					tarinput.position = pos;
				}
			}

			tarinput.position = (tarinput.position + size + 511) & (~511);
		}

		sys.FileSystem.createDirectory(output);

		var tmpbuf = haxe.io.Bytes.alloc(64 << 10); 

		for (a in assets) {
			trace('Unpacking ${a.path}');

			if (a.size == null || a.content_offset == null) continue;

			var file = haxe.io.Path.join([output, a.path]);

			try {
				sys.FileSystem.createDirectory(haxe.io.Path.directory(file));
				
				var output = sys.io.File.write(file, true);
				tarinput.position = a.content_offset;
				format.tools.IO.copy(tarinput, output, tmpbuf, a.size);

				output.close();
			} catch (e : Dynamic) {
				trace('Error unpacking [$file] :\n${Std.string(e)}');
			}
		}
	}
}