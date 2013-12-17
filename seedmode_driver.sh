#!/bin/bash


# this client only seeds (nice guy)
(ruby Main.rb seed 6881 seed_dir1 dl_dir1 peerlist1.txt torrent_files/pizza.torrent &) > client1_output.txt

 
# normal seeding + leeching client
ruby Main.rb sd 6882 seed_dir2 dl_dir2 peerlist2.txt torrent_files/pizza.torrent

