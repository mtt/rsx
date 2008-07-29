#!/usr/bin/env ruby
#RSX Ruby Shell Explorer
#Lets us explore the filesystem from the command line
#Changing directory, opening files, etc is done by sending a signal
#to the parent shell.
#Pretty much useless without adding trap in startup script like .profile or .bashrc

require 'curses'
include Curses

#lines(y-axis) cols(x-axis)

class RSX
  
  #File that holds info that shell needs after RSX closes
  #i.e. directory to cd or file to vi
  @@tmp_file = '/tmp/rsx'

  class File
    
    attr_reader :path, :top, :left
    attr_writer :top

    def initialize(path,top,left)
      @path = path
      @name = ::File.basename(path)
      @top  =  top
      @left = left
    end

    def name
      "X #{@name}"
    end

    def left_min
      @left
    end

    def left_max
      @left + name.length
    end
  end

  class Dir < File
    
    def subs
      ::Dir["#{@path}/*"]
    end
    
    def has_subs?
      !subs.empty?
    end

    def name
      has_subs? ? "+ #{@name}" : "- #{@name}"
    end
  end

  def initialize
    @top =  0
    @left = 0
    @dir = ARGV[0] || '.'
    @line_assets = []
    init_draw
  end

  def up
    return if @top == 0
    @top -= 1
  end

  def down
    return if @top == lines
    @top += 1
  end

  def left
    return if @left == 0
    @left -= 1
  end

  def right
    return if @left == cols
    @left += 1
  end

  def enter
    if (dir = over_directory?)
      write_go_file_and_exit(dir) if over_directory_text?(dir)
      return unless dir.has_subs?
      tmp_top,tmp_left = @top,@left
      assets = delete_lines_under(dir)
      insert_new_directory_assets(dir)
      add_assets_to_end_of_line(assets)
      @top,@left = tmp_top,tmp_left
    elsif (file = over_file?)
      write_go_file_and_exit(file)
    end
  end

  def debug(c)
    @top,@left = 0,0
    addstr(c.to_s)
    draw
  end

  def draw
    setpos(@top,@left)
    refresh
  end

  def dirs
    @line_assets.select {|l| l.is_a? RSX::Dir}
  end

  def files
    @line_assets.select {|l| l.is_a? RSX::File}
  end

  def init_draw
    x =  0
    y =  0
    xd = 0
    yd = 1

    ::Dir["#{@dir}/*"].each do |f|
      setpos(y,x)

      if ::File.directory?(f)
        @line_assets << current = Dir.new(f,y,x)
      else
        @line_assets << current = File.new(f,y,x)
      end

      x += xd
      y += yd
      addstr(current.name)
    end
    setpos(0,0)
    refresh
  end

  private
 
    def over_directory?
      dirs.detect do |d|
        d.top == @top && @left >= d.left_min && @left <= d.left_max
      end
    end
 
    def over_file?
      files.detect do |f|
        f.top == @top
      end
    end

    def over_directory_text?(dir)
      @top == dir.top && @left >= dir.left + 2
    end

    def write_go_file_and_exit(dir) 
      ::File.open(@@tmp_file,"w") {|f| f << ::File.expand_path(dir.path) }
      `kill -s HUP #{Process.ppid}`
      exit
    end
    
    def delete_lines_under(dir)
      lines_to_del = @line_assets.size - @top - 1
      return [] if lines_to_del <= 0
      setpos(@top + 1,@left)
      assets_to_shift = []
      lines_to_del.times do 
        deleteln 
        assets_to_shift <<  @line_assets.pop
      end 
      refresh
      assets_to_shift.reverse
    end

    def insert_new_directory_assets(dir)
      dir.subs.each do |f|
        @top += 1
        @left = dir.left + 2
        setpos(@top,@left)
        if ::File.directory?(f)
          @line_assets << current = Dir.new(f,@top,@left)
        else
          @line_assets << current = File.new(f,@top,@left)
        end
        addstr(current.name)
      end     
    end

    def add_assets_to_end_of_line(assets)
      assets.each do |asset|
        @top += 1
        setpos(@top,asset.left)
        asset.top = @top
        @line_assets << asset
        addstr(asset.name)
      end
    end

    def debug(msg)
      setpos(lines/2,cols/2)
      addstr(msg)
      refresh
      sleep(1)
    end
end


init_screen


begin
  crmode
  noecho 
  stdscr.keypad(true)
  b = RSX.new
  c = ''
  loop do
    case c = getch
    when ?q          : break
    when Key::UP,?u     : b.up 
    when Key::DOWN,?m   : b.down
    when Key::LEFT,?h   : b.left
    when Key::RIGHT,?k  : b.right
    when ?d : deleteln
    when ?c : delch
    when 10 : b.enter
    else 
    end
   b.draw 
  end

ensure
  close_screen
end
