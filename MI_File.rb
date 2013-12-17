class MI_File

  @length
  @path # this contains a qualified directory in an array including the file-name, begins from top_level_directory (exclusive)

# fd = file descriptor
  attr_accessor :path, :length, :fd
  def initialize(path, length)

    @DEBUG = 0

    if(@DEBUG == 1) then
      puts "PATH #{path}"
      puts "LEGNTH #{length}"
    end

    @length = length
    @path = path
    @fd = nil

  end

  # class ends here
end
