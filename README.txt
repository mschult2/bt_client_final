Michael & Ivan - BT Client


Program usage:

ruby Main.rb [seed|sd] <servPort> <seed_dir> <dl_dir> [<peerlist>|null] <torrentfiles> ...

seed : start in pure seed mode (no leeching, seeds from seed_dir)

sd : start in normal mode (downloads to dl_dir, seeds from seed_dir)

All arguments are mandatory.  

You can only use seed OR sd as an argument.

The servPort is the port you want to seed on.

The seed directory are the files you seed, the dl_dir are where you put files
as you download them.  As of right now, we can only seed from and download to 
different places; this means you won't be able to seed the file as you download it.
You have to download it completely, and then you can seed it.
Still a single instance of our client can seed and leech simultaneously.  However,
it has to be the same file.

The peerlist is a list of IPs and port numbers you want to hardcode as peers (don't
need to go through the tracker to get them).  They are added on top of the peers 
returned by the tracker.  You don't actually need a peerlist,
although you do need a peerlist argument.  So just type "null", or any word which isn't
a filename in your local directoy, for that argument if you don't want a peerlist 
The format of the peerlist is:
<ip_addr> <port_num>
<ip_addr> <port_num>


At the end, you can list multiple torrent files.  They will be downloaded simultaneously.
The torrent files are navigated to from the current directory.

This is your only chance to enter arguments; the command line goes away when the program
starts running.



Program behavior:

You generally want to run in ds mode; that's the normal mode.  

The program will continue seeding after it finishes downloading.  The only way to end it
is to kill the process (if you cntrl+c, you will still have to kill the process).

Our program does not handle multi-file torrents or UDP trackers.

IMPORTANT NOTE - If a piece at the end of the file is shorter than the rest, our
program will pad the data such that the resulting file is a tiny bit bigger and will
not diff correctly with the original.  HOWEVER, it is still the same file, and will
still function in exactly the same way, it will not be corrupted or incomplete, and we 
are still doing an internal hash check to make sure all the incoming pieces are correct.




Bash Scripts:
clientTalk_driver.sh -
There is a the most important script which demonstrates two instances of the client seeding and 
leeching to each other simultaneously on different ports.  They have been hardcoded
into the peerlist, because we are using a torrent we made ourself for the sake of
this demonstration, and we couldn't find a public tracker that would take it.  So instead,
we use the peerlist to bypass the tracker and get get peer addresses to our clients 
anyway.

seedmode_driver.sh -



Directories:

Complete files to be seeded go in <seed_dir>.
Files that are being downloaded go in <dl_dir>.
Torrent files (*.torrent) can technically go anywhere, but we put them in torrent_files/.



