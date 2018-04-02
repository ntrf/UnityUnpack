
import sys.io.File;

import format.gz.Reader;

typedef AssetDesc = {
	@:optional var path : String;
	@:optional var content_offset : Int;
	@:optional var size : Int;
	@:optional var meta_offset : Int;
	@:optional var meta_size : Int;
};

class UnityUnpack
{
	static var paxheader = ~/PaxHeader/i;

	static var asset_content = ~/\/asset$/i;
	static var asset_path = ~/\/pathname$/i;
	static var asset_meta = ~/\/asset\.meta$/i;

	static function main()
	{
		var args = Sys.args();

		if (args.length <= 0) {
			Sys.println("Unity package unpacker\n");
			Sys.println("Usage:\n    unityunpack [--nometa] <.unitypackage> [<output_directory>]\n");
			Sys.println("    --nometa   don't unpack meta files\n");
			return;
		}

		var nometa = false;

		var args_start = 0;
		while(true) {
			var a = args[args_start];
			if (a == "--nometa") {
				nometa = true;
			} else {
				break;
			}

			++args_start;
		}

		var input = new haxe.io.Path(args[args_start]);
		var output = './${input.file}';

		if (args.length >= args_start + 2) {
			output = args[args_start + 1];
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
				} else if (asset_meta.match(fname)) {
					if (!nometa) {
						a.meta_offset = tarinput.position;
						a.meta_size = e.fileSize;
					}
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

			var file = haxe.io.Path.join([output, a.path]);

			if ((a.size == null || a.content_offset == null) && 
				(a.meta_size == null || a.meta_offset == null)) continue;

			try {
				sys.FileSystem.createDirectory(haxe.io.Path.directory(file));
				
				if (a.size != null || a.content_offset != null) {
					var output = sys.io.File.write(file, true);
					tarinput.position = a.content_offset;
					format.tools.IO.copy(tarinput, output, tmpbuf, a.size);
					output.close();
				}

				if (a.meta_size != null && a.meta_offset != null) {
					var output = sys.io.File.write(file + ".meta", true);
					tarinput.position = a.meta_offset;
					format.tools.IO.copy(tarinput, output, tmpbuf, a.meta_size);
					output.close();
				}

			} catch (e : Dynamic) {
				trace('Error unpacking [$file] :\n${Std.string(e)}');
			}
		}
	}
}