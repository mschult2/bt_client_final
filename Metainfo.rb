require './bencode.rb'
require 'digest/sha1'
require './MI_File.rb'
require 'timeout'
require 'monitor'
require 'fileutils'

class Metainfo

  attr_accessor :trackers, :info_hash, :piece_length, :pieces, :num_pieces,
  :name, :multi_file, :top_level_directory, :file_array, :peers, :good_peers,
  :peer_threads, :bitfield, :piece_length, :block_request_size, :torrent_length,
  :current_piece, :seed_files_dir, :servPort, :peerlist_filename, :piece_hashes,
  :first_time, :cur_time, :prev_time, :dl_dir

  @dl_dir
  @cur_time
  @prev_time
  @first_time
  @peerlist_filename
  @servPort
  @trackers
  @info_hash
  @piece_length
  @pieces
  @peers
  @num_pieces
  @multi_file
  @top_level_directory
  @file_array
  @peer_id
  @good_peers
  @timeout_val
  @bitfield
  @block_request_size
  @torrent_length
  @file_buffer
  def initialize(file_location, servPort, peerlist_filename, seed_dir, dl_dir)

    @dl_dir = dl_dir
    @first_time = 0

    # this is the users personal list of peers
    @peerlist_filename = peerlist_filename
    
    # This is the port of our listener, or server, or seeder.  All he does is seed,
    # on a constant port specified at the command line
    @servPort = servPort

    @seed_files_dir = seed_dir

    # keep_alive has an id of -1, it is treated specially for our implementation - it's length is zero
    @keep_alive_id = -1

    # these do not have a payload
    @choke_id = 0
    @unchoke_id = 1
    @interested_id = 2
    @not_interested_id = 3

    # these have a payload
    @have_id = 4
    @bitfield_id = 5
    @request_id = 6
    @piece_id = 7
    @cancel_id = 8
    @port_id = 9

    # FOR DEBUGGING, TEMPORARY
    @current_piece = 0
   

    @DEBUG = 0
    # five second timeout
    @timeout_val = 5

    #################################################
    # IMPORTANT, CURRENTLY NOT ADDING UDP TRACKERS ##
    #################################################

    # get the trackers

    @trackers = Array.new
    @buffer = Array.new

    dict = BEncode::load(File.new(file_location))

    @piece_length = dict["info"]["piece length"]
    @num_pieces = (dict["info"]["pieces"].length / 20)
    @piece_hashes = Array.new
    @peer_id = "MI000167890123456789"
    # @peer_id =  "-AZ2060-123495832949"
    @good_peers = Array.new

    @top_level_directory = dict["info"]["name"]
    @file_array = Array.new
    @bitfield = String.new
    @lock = Monitor.new
    @block_request_size = 16384 # this is in bytes 2^14

    if(dict["info"].include?("files")) then
      @multi_file = true
      puts "Can't handle multi-file torrents.  Exiting..."
      exit
      # Deal with all of the files
      dict["info"]["files"].each{|mi_file|
        curr_file = MI_File.new(mi_file["path"], mi_file["length"])
        @file_array.push(curr_file)
      }

    else
      @multi_file = false
      curr_file =  MI_File.new(dict["info"]["name"], dict["info"]["length"])
      @file_array.push(curr_file)

    end

    # go through all of the pieces, in sets of 20
    dict["info"]["pieces"].each_char.each_slice(20){|slice|

      temp_hash_string = String.new

      slice.each{|a_byte| temp_hash_string.concat(a_byte.to_s()) }

      @piece_hashes.push(temp_hash_string)

    }

    if @DEBUG == 1 then

      puts "Piece Length #{@piece_length}"
      puts (dict["info"]["pieces"].length / 20)

    end

    @torrent_length = 0
    # get the total torrent length
    @file_array.each{|file| @torrent_length = @torrent_length + file.length}

    if dict["announce"] != nil and not dict["announce"].include?("udp") then
      @trackers.push(dict["announce"])
    end

    if dict["announce-list"] != nil then
      dict["announce-list"].each{|t| if not (t[0].include?("udp")) then @trackers.push(t[0]) end}
    end

    # make sure that we do not have two copies of announce
    @trackers.uniq!

    # compute the info hash here

    @info_hash = Digest::SHA1.digest(dict["info"].bencode)

    #puts "HASH : " + Digest::SHA1.hexdigest(dict["info"].bencode)

    if(@trackers.size == 0) then
      puts "Zero trackers. Cannot proceed. Exiting."
      exit
    end

    # initialize bitfield to empty
    @bitfield = Bitfield.new(@num_pieces, self, false)

    if(@DEBUG == 1) then
      puts "The total number of pieces is : #{@num_pieces}"
      puts "The piece length is           : #{@piece_length}"
      puts "The block request size is     : #{@block_request_size}"
      puts "The total torrent length is   : #{@torrent_length}"
    end

    get_peers()

    # RESTART
    # if file exists partially in dl directory, load it into bitmap
    # load_a_file_into_leecher(@dl_dir + "/" + @top_level_directory) 

  end

  def seed()

    my_bitmap = load_a_file(@seed_files_dir + "/" + @top_level_directory)

    seed_sleep_amount = 0.05

    seed_thread = Thread.new(){
      server = TCPServer.new @servPort
      loop do

        client = server.accept    # Wait for a client to connect

        # recv the handshake
        message = client.recv 68

        message = message[0...68]

        # send out our handshake
        client.write message

        begin
          # send your bitfield
          #puts "MY VERY OWN BITFIELD : #{send_my_bitfield(my_bitmap).inspect}"
          client.write send_my_bitfield(my_bitmap)
          sleep(seed_sleep_amount)
          # unchoke the peer
          client.write create_unchoke().get_processed_message
        rescue
          puts $!, $@
        end

        # start our recv loop

        while true do

          begin
            data = client.recv 4
          rescue Errno::ECONNRESET
            #puts "Peer decided to disconnect.  Exiting seeder thread."
            #Thread.exit
            # break
          end

          length = data[0 ... 4].unpack("H*")[0].to_i(16)

         #  puts "I am about to recv #{length} bytes of data."

          additional_data = ""
          while (additional_data.length != length) do
            additional_data.concat(client.recv(length))
          end

          message_id = additional_data.each_byte.to_a[0]

         # puts "I Got a message ID #{message_id}"
         # puts "This is the data : #{additional_data.each_byte.to_a.inspect}"

          case message_id

          when @keep_alive_id

          when @choke_id

          when @unchoke_id

          when @interested_id

            @peer_interested = true
            client.write(create_unchoke().get_processed_message)

          when @not_interested_id

          when @have_id

          when @bitfield_id

          when @request_id

            #puts "SEEDER : I GOT A REQUEST FROM THE CLIENT FOR A PIECE"

            begin

              piece_index = additional_data[1...5].unpack("H*")[0].to_i(16)
              byte_offset = additional_data[5...9].unpack("H*")[0].to_i(16)
              requested_length = additional_data[9...13].unpack("H*")[0].to_i(16)

           #   puts "SEEDER : I am being asked for the #{piece_index} index with offset #{byte_offset} and size #{requested_length}"

              #puts "LENGTH OF BITMAP : #{my_bitmap.piece_field.length}"
              #puts "LENGTH OF BLOCKF : #{my_bitmap.piece_field[piece_index].block_field_data.length}"

              block_to_send = my_bitmap.piece_field[piece_index].block_field_data[(byte_offset / requested_length)]

              msg_arr = Array.new
              msg_length = 9 + @block_request_size
              msg_arr.push(msg_length)
              processed_length = msg_arr.pack("L>")

              msg_id_array = Array.new
              msg_id = 7
              msg_id_array.push(msg_id)
              processed_msg_id = msg_id_array.pack("C")

              msg_index_array = Array.new
              msg_index = piece_index
              msg_index_array.push(msg_index)
              processed_msg_index = msg_index_array.pack("L>")

              msg_begin_array = Array.new
              msg_begin = byte_offset
              msg_begin_array.push(msg_begin)
              processed_msg_begin = msg_begin_array.pack("L>")

              msg_block = block_to_send

              final_message = "#{processed_length}#{processed_msg_id}#{processed_msg_index}#{processed_msg_begin}#{msg_block}"

              # puts "MSG BLOCK LENGTH      #{msg_block.length}"
              # puts "FINAL MESSAGE LENGTH  #{final_message.length}"
              # puts "FINAL MESSAGE CONTENT #{final_message.inspect}"

              client.write(final_message)


            rescue
              puts $!, $@
            end

          when @piece_id

          when @cancel_id

          when @port_id

          else
            puts "You gave me #{message_id} -- I have no idea what to do with that."
            $stdout.flush

          end

          sleep(seed_sleep_amount)

        end
      end
    }

    return seed_thread

  end

  def add_to_good_peers(peer)
    @lock.synchronize do
      @good_peers.push(peer)
    end
  end

  def append_data(block_num, data)
    @lock.synchronize do
      if(@file_buffer[block_num].length == 0) then
        @file_buffer[block_num] = data
      end
    end
  end

  def increment_piece()
    @lock.synchronize do
      @current_piece = @current_piece + 1
    end
  end

  def delete_from_good_peer(peer)
    @lock.synchronize do
      if(@good_peers.include?(peer))
        @good_peers.delete(peer)
      end
    end
  end

  def set_bitfield(piece, byte)
    @lock.synchronize do

      @bitfield.set_piece_and_block(piece, byte)

      if(@bitfield.check_if_full(piece)) then
        @bitfield.set_bit(piece, true)
      end

    end
  end

  def get_peers()

    tracker_list = @trackers
    peers = Array.new

    # for each tracker, get the peer list

    tracker_list.each{|tracker|

      # parameter hash table
      params = Hash.new

      # fill out the parameter hash
      params["info_hash"] = @info_hash
      params["numwant"] = 200
      params["peer_id"] = @peer_id
      params["compact"] = 1
      params["left"] = 1
      params["uploaded"] = 0
      params["downloaded"] = 0
      params["port"] = @servPort
      params["event"] = "started"

      begin

        # create the tracker address
        uri = URI.parse(tracker)
        uri.query = URI.encode_www_form(params)

        res = ""
        # get request
        Timeout::timeout(@timeout_val){
          res = Net::HTTP.get_response(uri)
        }

        if res == "" then raise "Res is empty" end

        # read response
        res_dict = BEncode::load(res.body)

        # get the addresses
        addresses = res_dict["peers"]

        #  puts tracker

        addresses.each_byte.each_slice(6){|slice|

          port = slice[4] * 256
          port += slice[5]

          if port != 0 then

            byte_ip = Array.new
            byte_ip.push(slice[0])
            byte_ip.push(slice[1])
            byte_ip.push(slice[2])
            byte_ip.push(slice[3])

            string_ip = slice[0].to_s() + "." + slice[1].to_s() + "." + slice[2].to_s() + "." + slice[3].to_s()

            # Initialize our peer
            curr_peer = Peer.new(self, string_ip, port, byte_ip, @peer_id, @servPort)

            peers.push(curr_peer)

          end

        }

      rescue
        # nothing to be done here
        # puts "Encountered an error with tracker : " + tracker
        #puts $!, $@
      end

    }

    # Read in peers from peerlist.txt, if it exists in local directory.  The point 
    # of peerlist.txt is to be a set of hardcoded peers that we don't need 
    # to get from the tracker.
    if (File.exists?(@peerlist_filename)) then
      puts "Found peerlist.txt.  Adding peers..."
      lines_array = File.readlines(@peerlist_filename).map do |line|
        ip, port = line.split(" ")
        #puts ip
        #puts port
        peers.push(Peer.new(self, ip, port, nil, @peer_id, @servPort))
      end
    end
  

 #   our_ip = "127.0.0.1"
 #   our_port = @servPort
 #   peers.push(Peer.new(self, our_ip, our_port,nil,@peer_id, @servPort))

    #mike_ip = "10.109.172.3"
    #mike_port = @seed_port
    #peers.push(Peer.new(self, mike_ip, mike_port, nil, @peer_id))

    if(peers.size() == 0) then
      puts "We have no peers to talk to. Cannot proceed. Exiting."
      exit
    end

    @peers = peers

  end

  def spawn_peer_threads()

    puts "Starting to download #{@name}"

    @peer_threads = Array.new

    @peers.each{|peer|

      curr_thread = Thread.new(){
        run_algorithm(peer)
      }

      # wait for each thread to finish
      @peer_threads.push(curr_thread)
    }

  end

  def run_algorithm(peer)

    sleep_between = 0.05

    # handshake
    peer.handshake()

    sleep(sleep_between)

    if peer.connected == true then

      add_to_good_peers(peer)

      peer.send_msg(peer.create_interested())

      while true  do

        # If we have all the pieces, then exit!
        if @bitfield.full? then
          puts "\n~~~~~~~~~~~ #{@top_level_directory} download complete! ~~~~~~~~~~~"
          puts ""
          Thread.exit
        end

        sleep(sleep_between)

        a_message = peer.create_message()

        if(peer.peer_choking == false) then
          peer.send_msg(a_message)
        end

        sleep(sleep_between)
        peer.recv_msg()

      end

      peer.socket.close

    else
      return
    end

  end

  def send_my_bitfield(a_bitfield)

    begin
      # the + 1 is for the id
      bitfield_length = a_bitfield.byte_length() + 1
      id = "\x05";

      # this is used for packing
      temp = Array.new
      temp.push(bitfield_length)

      # the > specifies the endian-ness
      encoded_length = temp.pack("L>")

      bitfield_message = "#{encoded_length}#{id}#{a_bitfield.struct_to_string}"

    rescue
      puts $!, $@
    end

    return bitfield_message

  end

  def create_unchoke()

    return Message.new(@unchoke_id, 1, "")

  end

  def load_a_file(filename)


    seeder_bitmap = Bitfield.new(@num_pieces, self, false)

    begin

      blocks_per_piece = (@piece_length / @block_request_size)

      location = filename

      a_file = File.open(location, "rb")

      #read_file = a_file.read(@block_request_size)

      for i in (0 ... @num_pieces) do

        for j in (0 ... blocks_per_piece) do

          seeder_bitmap.piece_field[i].block_field_data[j] = a_file.read(@block_request_size)
          seeder_bitmap.piece_field[i].block_field[j] = true

        end

        # here we set the piece as being 'had'
        seeder_bitmap.bitfield[i] = true

      end

    rescue
      puts $!, $@
    end

    return seeder_bitmap

  end


def load_a_file_into_leecher(filename)


    

    begin

      blocks_per_piece = (@piece_length / @block_request_size)

      location = filename

      a_file = File.open(location, "rb")

      #read_file = a_file.read(@block_request_size)

      for i in (0 ... @num_pieces) do

        for j in (0 ... blocks_per_piece) do

          @bitfield.piece_field[i].block_field_data[j] = a_file.read(@block_request_size)
          @bitfield.piece_field[i].block_field[j] = true

        end

        # here we set the piece as being 'had'
        @bitfield.bitfield[i] = true

      end
      a_file.close
    rescue
      puts $!, $@
    end

   

  end



  def write_bitmap_to_file(bitmap)

    bitmap = File.new("output", "w")

    for i in (0 ... seeder_bitmap.piece_field.length) do

      for j in (0 ... seeder_bitmap.piece_field[i].block_field.length) do

        output_file.write(seeder_bitmap.piece_field[i].block_field_data[j])
        output_file.flush

      end
    end

    output_file.close
  end

  # class ends here
end

