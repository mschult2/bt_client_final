require './bencode.rb'
require './Metainfo.rb'
require './Peer.rb'
require 'net/http'
require 'uri'
require 'digest/sha1'
require 'fileutils'
require './Bitfield'
require 'fileutils'



am_seeder = false
am_leecher = true

if (ARGV[0] == "seed") then
  am_seeder = true
  am_leecher = false
 # puts "I am a SEEDER"
elsif (ARGV[0] == "dl") then
   # nothing, already not seeder
 #  puts "I am a LEECHER"
elsif (ARGV[0] == "sd")
  am_seeder = true
  am_leecher = true
 # puts "I am a LEECHER and a SEEDER!"
else
  puts "Invalid syntax(1).  Appropriate arguments are \"[dl|seed|ds] <filenames>\".  Exiting..."
    exit
end

# Parse out server port
servPort = ARGV[1]

# parse out save directory
save_dir = ARGV[2]
if (!File.directory?(save_dir)) then
  # if directory doesn't exist, then make it
  # Dir.mkdir(save_dir)
end

# parse out load directory
dl_dir = ARGV[3]
if (!File.directory?(dl_dir)) then
  # if directory doesn't exist, then make it
 Dir.mkdir(dl_dir)
end

# pars out peerlist
peerlist_filename = ARGV[4]

filenames = Array.new
i = 5
while ARGV[i] != nil
  filenames.push(ARGV[i])
  i += 1
end

if filenames.empty? then 
  puts "Invalid syntax(2); filenames must not be empty.  Appropriate arguments are \"[dl|seed|ds] <filenames>\".  Exiting..."
  exit 
end

# make sure files actually exists (and is not size zero!)
filenames.each { |filename|
  if (!File.exists?(filename)) then
    puts "Torrent file \"#{filename}\" does NOT exist!  Exiting..."
    exit
  end
}


seed_thread = nil

# we take a comma separated list of trackers
torrents = filenames

meta_info_files = Array.new

# for each tracker, get an associated meta-info file.
torrents.each{|torrent|
  meta_info_files.push(Metainfo.new(torrent, servPort, peerlist_filename, save_dir, dl_dir))
}

# If seeding, make sure metainfo file contains the correct name 
# (seeder data files should be located in Metainfo.seed_files_dir
if (am_seeder) then
  meta_info_files.each{|meta_info_file|
    datafile_name = meta_info_file.seed_files_dir + "/" + meta_info_file.top_level_directory

    if (!File.exists?(datafile_name)) then
      puts "Data file #{datafile_name} does NOT exist!  Creating..."
      FileUtils.touch(datafile_name)
    end
  }
end

meta_info_files.each{|meta_info_file|

if(am_seeder) then
  # THIS IS WHERE WE START SEEDING - the reason this works is because this only one meta-info file
  seed_thread = meta_info_file.seed()

  # THIS LITTLE BIT OF TIME IS FOR THE SERVER FIRING UP
  sleep(1)
end

  # make top level directory, if necessary.
  if (meta_info_file.multi_file == true) then
    #FileUtils.mkdir(meta_info_file.top_level_directory)
  end

  # Make the rest of the directory tree.
  if (meta_info_file.multi_file == true) then
    puts "Path has to be interpreted as dictionary for multi-file, cant open"
    puts "exiting..."
    exit
  else
    if (!(am_seeder == true && am_leecher == false)) then
    meta_info_file.file_array[0].fd =
    File.open(dl_dir + "/" + meta_info_file.file_array[0].path, "w")
end
  end



if (am_leecher) then
  meta_info_file.spawn_peer_threads()
end
}

if (am_leecher) then
# wait for the meta_info_peers to finish
meta_info_files.each{|meta_info_file|
  meta_info_file.peer_threads.each{|peer|
    peer.join
  }
  puts "The tracker gave me #{meta_info_file.peers.length} peers"
  puts "I have #{meta_info_file.good_peers.length} good peers"
}
end

# clean up
meta_info_files.each{ |meta_info_file|
  if (meta_info_file.multi_file == true) then
    puts "Path has to be interpreted as dictionary for multi-file, cant close"
    puts "exiting..."
    exit
  else
if (!(am_seeder == true && am_leecher == false)) then
    meta_info_file.file_array[0].fd.close
end
  end
}

if(am_seeder) then
  seed_thread.join
end





