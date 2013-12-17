require './Piece.rb'

class Bitfield
  attr_accessor :bitfield, :byte_length, :blockfield, :piece_field

  @bitfield
  @byte_length
  @meta_info_file
  @piece_field
  def initialize(length, meta_info_file, is_peer)

    @meta_info_file = meta_info_file

    @bitfield = Array.new
    @piece_field = Array.new

    for counter in 0...length
      @bitfield.push(false)
    end

    if not is_peer then

      for counter in 0 ... (length -  1)
        @piece_field.push(Piece.new(@meta_info_file.block_request_size, @meta_info_file.piece_length))
      end

      # take care of the last piece
      if not (@meta_info_file.torrent_length % @meta_info_file.piece_length == 0) then
        @piece_field.push(Piece.new(@meta_info_file.block_request_size, @meta_info_file.torrent_length % @meta_info_file.piece_length))
      else
        # add a normal piece
        @piece_field.push(Piece.new(@meta_info_file.block_request_size, @meta_info_file.piece_length))
      end

    else
      @piece_field = nil
    end

    @byte_length = (@bitfield.length / 8.0).ceil

  end

  def get_random_block(piece_index)

    if(piece_index == nil) then return nil end

    current_Piece = @piece_field[piece_index]
#    if (current_Piece == nil) then
#      puts "No more pieces; download complete (get_random_block())!"
#      exit
#    end
    piece_block_field = current_Piece.block_field
    missing_block_indices = Array.new

    for i in (0 ... piece_block_field.length) do
      if(piece_block_field[i] == false) then missing_block_indices.push(i) end
    end

    random_location = rand(0 ... missing_block_indices.length)

    if not (random_location == nil) then
      return missing_block_indices[random_location]
    else
      return nil
    end

  end

  # This method converts the data structure to the sendable bitmap
  def struct_to_string()

    # This function indexes 0 at the left end of the byte

    bitfield_string = String.new

    @bitfield.each_slice(8){|slice|

      curr_byte = 0

      for i in (0 ... slice.length) do

        if(slice[i] == true) then
          # Magic !!!
          curr_byte += (2 ** (7 - i))
        end
      end

      bitfield_string.concat(curr_byte.chr)

    }

    return bitfield_string

  end

  # this method syncs the bitmap input with the underlying bit array
  def set_bitfield_with_bitmap(input)

    offset = 0
    input.each_char{|curr_char|

      mike = 0
      for i in (0 ... 8) do

        mike = curr_char.each_byte.first & (2 ** (7 - i))

        if(mike != 0) then
          @bitfield[offset + i] = true
        end

      end
      offset += 8

    }

  end

  def struct_to_ones_and_zeroes()
    output = String.new

    counter = 1

    for i in (0 ... @bitfield.length) do
      if(@bitfield[i] == true) then
        output.concat("1")
      else
        output.concat("0")
      end

      if(counter % 8 == 0) then
        output.concat(" ")
      end
      counter = counter + 1
    end

    return output
  end

  def check_if_full(n)

    block_field_n = @piece_field[n].block_field

    full = true

    for i in (0 ... block_field_n.length) do
      if(block_field_n[i] == false) then
        full = false
        break
      end
    end

    return full

  end

  def set_piece_and_block(piece, byte)

    # NOTE, NOT TAKING CARE OF REINEER BLOCKS

    @piece_field[piece].block_field[(byte / @meta_info_file.block_request_size)] = true

  end

  def set_bit(n, t_or_f)

    if(n < 0 || n >= @bitfield.length) then
      raise "Out of bounds bitfield operation"
    end

    if(t_or_f == true) then @bitfield[n] = true else @bitfield[n] = false end

  end




def full?
am_full = true
  @bitfield.each{|piece|
    if piece == false then
      am_full = false
      break
    end
  }
return am_full
end




end


