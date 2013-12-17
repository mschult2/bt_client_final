#!/bin/bash

# This driver script creates two BT clients, and has them send files to each other.
# They are hardcoded as each others' only peers (the tracker won't return any peers for
# this torrent)

# This first instance of the client is seeding from server port 6881. 
# He has one hardcoded peer, the localhost at port 6882.
# His download directory is dl_dir1.

(ruby Main.rb sd 6881 seed_dir1 dl_dir1 peerlist1.txt torrent_files/pizza.torrent &) > client1_output.txt

 
# This second instance of the client is seeding from server port 6882.
# He has one hardcoded peer, the localhost at port 6881.
# 
ruby Main.rb sd 6882 seed_dir2 dl_dir2 peerlist2.txt torrent_files/pizza.torrent


