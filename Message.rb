class Message

  attr_accessor :id, :length, :payload
  # keep-alive messages have an id of -1, length of length of 4 and payload of nil
  def initialize(id, length, payload)

    # This field is parsed
    @id = id

    # This field is parsed
    @length = length

    # This field is not parsed (literally the bytes we were sent)
    @payload = payload
  end

  def get_processed_message()

    id_array = Array.new
    length_array = Array.new

    id_array.push(@id)
    length_array.push(@length)

    processed_id = id_array.pack("C")
    processed_length = length_array.pack("L>")

    return "#{processed_length}#{processed_id}#{@payload}"

  end
end
