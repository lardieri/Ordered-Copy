# Ordered Copy

**Ordered Copy**, `ocp`, is a Mac command-line tool to copy MP3 files onto a flash storage device for use with an external player.

It copies files onto the flash drive’s file system in the same order you would naturally play them. This is useful for players that can only follow the file system order.

Although designed primarily for MP3 files, `ocp` can copy other types of files, too. It sorts them alphabetically by their filenames.

## Usage

```
ocp [ -R ] [ --include ext,ext,... | --exclude ext,ext,... | --include-all [ --include-hidden ] ] [ --sort tag,tag,... ] source-directory destination-directory
```

### Required Parameters

`source-directory` : Path to the directory with the files to copy. Example: `~/Music/MP3s`

`destination-directory` : Path to the directory that receives the files. Example: `/Volumes/SD-card`

If `destination-directory` doesn’t exist, `ocp` attempts to create it.

All files in `source-directory` that meet the criteria specified below get copied. There is no way, and no need, to specify individual files. You can use `cp` for that.

### Optional Parameters

#### Subdirectories

`-R` : Recursively copy all subdirectories under `source-directory`. The default is to copy only files that are in `source-directory`.

#### Selection

`--include` : Copy **only** files of the specified types. Example: `--include mp3,ac3,wma`

`--exclude` : Copy all files **except** files of the specified types. Example: `--exclude jpg,png`

`--include-all` : Copy all files, except hidden files (unless `--include-hidden` is specified).

`--include-hidden` : Copy files and directories that start with a dot (`.`). The default is not to copy these.

You can only specify one of `--include`, `--exclude`, or `--include-all`.

If you specify none of them, the default is `--include mp3`.

#### Sorting

`--sort` : How to order MP3 files. Specify one or more tags in tie-breaking order. The available tags are:
- `album`
- `artist`
- `filename`
- `title`
- `track`

The default is `--sort artist,album,track,filename`.

You can’t have two files with the same name in the same directory, so `filename` always breaks a tie.

MP3 files without ID3 tags, and files that are not MP3, get ordered by filename and come after MP3 files with ID3 tags.

Subdirectories always come after files.

## Why does this exist?

Many consumer media devices, such as car stereos and digital picture frames, play or display files in the same order those files were originally copied onto the USB flash drive or SD card. They ignore filenames and any embedded metadata, such as titles or track numbers, that could be used to sort the files logically.

This means the order in which you copy files onto your storage device is important.

If you use a Windows PC to copy your media collection, that’s generally not a problem. Windows Explorer copies files in the same order you select or sort them, and Windows Media Player copies music in playlist order. 

On a Mac, however, it’s a different story. The way you choose to sort or arrange files in Finder has no bearing on how they get copied. Both Finder and the Terminal command `cp -R` copy files and folders based on the order they appear in the internal data structures of the Mac’s file system. Use the Terminal command `ls -f` to see your files in that order. It’s not exactly random, but might as well be.

Ordered Copy was written to address this.

In each directory that it copies, `ocp` scans all the files first, then determines the correct order to write them out. This may be alphabetical by filename, or it may be based on metadata that appears in MP3 files, such as track number.

While `ocp` can copy files anywhere, it’s meant to be used with external storage devices that are formatted with FAT32 or exFAT file systems. These file systems use a linear structure to store the list of files in each directory. Each new file or folder gets added to the end of the list. That’s why the order in which files get copied onto a storage device determines the order in which they get played.

## Limitations

### Double dipping

Ordered Copy is designed to copy an entire collection onto a freshly-formatted storage device. If you go back and add new files or folders to an existing storage device, they get placed at the end, regardless of how you copy them.

For example:
- Your USB flash drive has folders called ABBA, Beatles, and Creedence Clearwater Revival.
- You copy a new folder called Alphaville onto the flash drive.
- Your car stereo plays ABBA, Beatles, Creedence Clearwater Revival, Alphaville in that order.

Unfortunately, that’s just the way FAT32 and exFAT work. There is a tool called **FATSort** that can help with this.

Alternatively, you could erase the flash drive and then use `ocp` to copy your entire collection (including Alphaville) back onto it in the correct order.

(If you are a file system nerd: yes, deleted slots can be reused, so it’s not _strictly_ true that new files always get added at the end. Now just use the tool and enjoy it.)

### Other music formats

Reading ID3-like tags in other music formats (WMA, etc.) is not currently supported.

### Sorting filenames with numbers

Sorting by filename is naïve with respect to numbers. 10 comes before 2, for example. If your MP3s have filenames that incorporate track numbers, use “02” instead of “2” to work around this.

## Credits

chicio’s **ID3TagEditor:** [https://github.com/chicio/ID3TagEditor](https://github.com/chicio/ID3TagEditor)

DivineDominion’s **FileExistence:** [https://christiantietze.de/posts/2017/01/file-existence-swift/](https://christiantietze.de/posts/2017/01/file-existence-swift/)
