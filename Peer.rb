require 'timeout'
require './Message.rb'
require 'digest/sha1'

class Peer

  attr_accessor :string_ip, :byte_ip, :port, :info_hash, :connected, :bitfield, :socket, :peer_choking, :servPort, :time, :first_time
  def initialize(meta_info_file, string_ip, port, byte_ip, peer_id, servPort)

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

    @meta_info_file = meta_info_file
    @pstr = "BitTorrent protocol"
    @pstrlen = "\x13"
    @reserved = "\x00\x00\x00\x00\x00\x00\x00\x00"
    @string_ip = string_ip
    @port = port
    @servPort = servPort
    @byte_ip = byte_ip
    @peer_id = peer_id
    @info_hash = meta_info_file.info_hash
    @handshake_info = "\x13BitTorrent protocol\x00\x00\x00\x00\x00\x00\x00\x00#{info_hash}#{peer_id}"
    @bitfield = Bitfield.new(meta_info_file.num_pieces, meta_info_file, true)

    @connected = false

    @peer_choking = true
    @peer_interested = false
    @am_choking = true
    @am_interested = true

    @timeout_val = 10

    # not set here
    @last_recv_time
    @last_sent_time

    @DEBUG = 0

    if @DEBUG == 1 then
      puts "--- PEER CONSTRUCTED ---"
      puts "pstr      : #{@pstr}"
      puts "pstrlen   : #{@pstrlen}"
      puts "reserved  : #{@reserved}"
      puts "info_hash : #{@info_hash}"
      puts "peer_id   : #{@peer_id}"
      puts "string_ip : #{@string_ip}"
      puts "byte_ip   : #{@byte_ip}"
      puts "port      : #{@servPort}"
      puts "handshake : #{@handshake_info}"
      puts "--- PEER CONSTRUCTED ---"
    end

  end

  def handshake()

  #  puts "I AM SENDING A HANDSHAKE TO IP #{@string_ip} at port #{@port}"

    begin

      Timeout::timeout(@timeout_val){

        @socket = TCPSocket.new(@string_ip, @port)

        @socket.write @handshake_info

        handshake = @socket.read 68

        if(handshake[28..47] != @info_hash) then
          Thread.exit
        end

        @connected = true

      }

      if @connected then
        puts "Handshake with peer : #{@string_ip} was successful."
      else
        puts "Handshake with peer : #{@string_ip} was not successful."
      end

    rescue
      puts "could not connect to : " + @string_ip
      $stdout.flush
    end

  end

  # documentation :
  # this method receives a message from the peer and parses the message
  # said message returns a message data structure, return nil if timeout

  def recv_msg()

    debug = false

    begin

      Timeout::timeout(@timeout_val){

        length = 0
        id = 0
        data = @socket.recv(4)

        # make sure we actually got something
        if data == nil then
          #@meta_info_file.delete_from_good_peer(self)
          #Thread.exit
        end

        length = data[0 ... 4].unpack("H*")[0].to_i(16)

        #puts "I am about to get #{length} bytes of data"

        additional_data = ""

        #puts "Length :#{length}"
        #$stdout.flush

        begin
          while (additional_data.length != length) do
            additional_data.concat(@socket.recv(length))
          end
        rescue
          message_id = 999
          #puts "Hit the integer snag"
        end

        #puts "ADVRTIZD LENGTH : #{Thread.current.object_id} #{length}"
        #puts "ADDITION LENGTH : #{Thread.current.object_id} #{additional_data.each_byte.to_a.length}"

        $stdout.flush

        # if you are not sending as much data as you advertise, we drop you BOOM
        if(additional_data.each_byte.to_a.length != length) then
          #@meta_info_file.delete_from_good_peer(self)
          #Thread.exit
        end

        if(debug) then
          puts "length of data to be recvd : #{length}"
          puts "length of data recv'd      : #{additional_data.each_byte.to_a.length}"
        end

        if(length != 0 && message_id != 999) then
          message_id = additional_data.each_byte.to_a[0]
        else
          message_id = -1
        end

        new_message = Message.new(message_id, length, additional_data[1...additional_data.length])

        # update recv time
        @last_recv_time = Time.new

        case message_id

        when @keep_alive_id
          #puts "I got a KEEP-ALIVE id, code doesn't do anything about this yet"

        when @choke_id
          @peer_choking = true
          #puts "I got choke id"

        when @unchoke_id
          #puts "CLIENT : I got unchoked"
          #puts "i am unchoking"
          @peer_choking = false
          #puts "I got unchoke_id"

        when @interested_id
          @peer_interested = true

          #unchoke the peer if he is interested
          send_msg(Message.new(@unchoke_id, 1, ""))
          @am_choking = false

        when @not_interested_id
          @peer_interested = false
          puts "I got not_interested_id"

        when @have_id

          # update bitfield

          # Parse out numberic bitIdx
          bitIdx = 0
          bitIdx += new_message.payload().each_byte.to_a[0] * (2 ** 24)
          bitIdx += new_message.payload().each_byte.to_a[1] * (2 ** 16)
          bitIdx += new_message.payload().each_byte.to_a[2] * (2 ** 8)
          bitIdx += new_message.payload().each_byte.to_a[3]

          # Update corresponding bitIdx in bitfield
          @bitfield.set_bit(bitIdx, true)

          #puts "I got have_id: #{bitIdx}"

        when @bitfield_id

          #puts new_message.payload().each_byte.to_a.length
          @bitfield.set_bitfield_with_bitmap(new_message.payload())
          #puts "I got bitfield_id"

        when @request_id

          # puts "I got request_id"

        when @piece_id

          #puts "I got piece_id"
          #puts "I got a piece from #{@string_ip}"

          payload =  new_message.payload

          # 4 bytes = length
          # 1 byte = id
          # ---------------
          # index = 4 bytes
          # begin = 4 bytes

          index = payload[0 ... 4]
          byte_begin = payload[4 ... 8]
          block_data = payload[8 ... (payload.length)]

          index = index.unpack("L>")[0]
          byte_begin = byte_begin.unpack("L>")[0]
          block_idx = byte_begin / (@meta_info_file.block_request_size)

          # puts "given block index: #{block_idx}"

          #puts "Index     : #{index}"
          #puts "Byte begin: #{byte_begin}"

          prev_piece_status = @meta_info_file.bitfield.bitfield[index]
          @meta_info_file.set_bitfield(index, byte_begin)
          cur_piece_status = @meta_info_file.bitfield.bitfield[index]

          # Store block_data in memory.
          @meta_info_file.bitfield.piece_field[index].block_field_data[block_idx] = block_data

          if(prev_piece_status == false && cur_piece_status == true) then


            
            # check piece hash, but not for rainier piece
            hash_same = true
          if (! (index == @meta_info_file.num_pieces - 1) ) then
            
            piece_str = ""
            @meta_info_file.bitfield.piece_field[index].block_field_data.each{|block|
              piece_str = piece_str + block
            }
            
            # do hash of piece str and compare to original
            # @info_hash =  Digest::SHA1.digest(dict["info"].bencode)
            rcvd_hash = Digest::SHA1.digest(piece_str)
            actual_hash = @meta_info_file.piece_hashes[index]

            if (rcvd_hash != actual_hash) then
              hash_same = false
              puts "HASHES DIFFER!!!!!!!  Skip this piece..."
              return
            end
         end



   
            @meta_info_file.cur_time = Time.now

           
#            puts "Writing piece #{index} to disk, the torrent is #{((((index+1).to_f / @meta_info_file.num_pieces).to_f)*100).round(2)} % complete. (#{((index+1) * @meta_info_file.piece_length) / 1024} kb downloaded)" 

            #write piece to disk
            print "#{@meta_info_file.top_level_directory} #{((((index+1).to_f / @meta_info_file.num_pieces).to_f)*100).round(2)} % complete. (#{((index+1) * @meta_info_file.piece_length) / 1024} kB downloaded)   -   peers: #{@meta_info_file.good_peers.length} / #{@meta_info_file.peers.length}   -   "

            # calculate download rate
            if (@meta_info_file.first_time == 0) then
              puts ""
              @meta_info_file.first_time = 1
            else
              time_diff = @meta_info_file.cur_time - @meta_info_file.prev_time
              amount_dled = @meta_info_file.piece_length / 1024 # in kB
              kBps = amount_dled / time_diff
              kBps = kBps.round(0)
              puts "dl rate: #{kBps} kB/s"
            end

            @meta_info_file.prev_time = @meta_info_file.cur_time

            if (@meta_info_file.multi_file == true) then
              puts "in Peer.recv_msg, dont know how to write out piece for multifile.  Exiting..."
              exit
              
            else
              @meta_info_file.bitfield.piece_field[index].block_field_data.each{|block|
                @meta_info_file.file_array[0].fd.write(block)
                @meta_info_file.file_array[0].fd.flush

              }
              # @meta_info_file.file_array[0].fd.close
              # exit

            end

            #remove piece from memory
          end

          $stdout.flush

        when @cancel_id
         puts "I got cancel_id"

        when @port_id
         puts "I got port_id"

        else
          puts "You gave me #{message_id} -- I have no idea what to do with that."
          $stdout.flush
          #@meta_info_file.delete_from_good_peer(self)
          #Thread.exit
        end

        $stdout.flush

      }

    rescue Timeout::Error => e
      #puts $!, $@
      #puts "Encountered a timeout error."
      #@meta_info_file.delete_from_good_peer(self)
      #Thread.exit

    rescue Errno::ECONNRESET => e
      #puts "Connection Reset by peer."
      #@meta_info_file.delete_from_good_peer(self)
      #Thread.exit

      #  rescue # any other error
      # puts $!, $@
      #puts "Encountered a non-timeout error."
      # @meta_info_file.delete_from_good_peer(self)
      #Thread.exit
    end

  end

  def send_my_bitfield()

    # I NEED A TRY - CATCH

    # the + 1 is for the id
    bitfield_length = @meta_info_file.bitfield.byte_length + 1
    id = "\x05";

    # this is used for packing
    temp = Array.new
    temp.push(bitfield_length)

    # the > specifies the endian-ness
    encoded_length = temp.pack("L>")

    bitfield_message = "#{id}#{encoded_length}#{@meta_info_file.bitfield.struct_to_string}"

    @socket.write bitfield_message

  end

  def send_msg(message)

    begin

      msg = message.get_processed_message()
      #puts msg.inspect

      #puts "Wrote #{@socket.write(msg)} bytes"
      @socket.write(msg)

    rescue
      #puts "Problem sending message. Probably a broken pipe."
      #puts $!, $@
      #@meta_info_file.delete_from_good_peer(self)
      #Thread.exit
    end
  end

  def get_random_piece()

    common_pieces_indices = Array.new
    peer_bitfield = @bitfield.bitfield
    our_bitfield = @meta_info_file.bitfield.bitfield

    for i in (0 ... our_bitfield.length) do

      if(peer_bitfield[i] == true && our_bitfield[i] == false) then common_pieces_indices.push(i) end

    end

    # we now know the indices of the pieces which the peer has but we do not
    random_location = rand(0 ... common_pieces_indices.length)

    if(random_location == nil)
      return nil
    else
      return common_pieces_indices[random_location]
    end

  end

  def create_message()

    if(@peer_choking) then
      # if the peer is choking us, we want to express our interest in her
      return Message.new(@interested_id, 1, "")
    else

      # if the peer is not choking us, we want a piece of her
      #random_piece = get_random_piece()

      curr_piece = @meta_info_file.current_piece

      random_piece = curr_piece

      if(random_piece != nil) then

        # we create the piece request payload right here

        # process the random piece
        random_piece_array = Array.new
        random_piece_array.push(random_piece)
        processed_random_piece = random_piece_array.pack("L>")
        payload_index = processed_random_piece

        # process the random block - this is the offset into the piece
        random_block = @meta_info_file.bitfield.get_random_block(random_piece)

        if(random_block == nil) then @meta_info_file.increment_piece(); return self.create_message() end

        random_block = random_block * @meta_info_file.block_request_size
        random_block_array = Array.new
        random_block_array.push(random_block)
        processed_random_block = random_block_array.pack("L>")
        payload_begin = processed_random_block

        # get the length of the block which we are requesting
        block_length_array = Array.new
        block_length_array.push(@meta_info_file.block_request_size)
        processed_block_length = block_length_array.pack("L>")
        payload_length = processed_block_length

        payload = "#{payload_index}#{payload_begin}#{payload_length}"

        return (Message.new(6, 13, payload))

      else
        return nil
      end

    end

  end

  def create_interested()

    return Message.new(@interested_id, 1, "")

  end

end

