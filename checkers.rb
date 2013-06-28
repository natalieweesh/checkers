# -*- coding: utf-8 -*-
require 'colorize'

class InvalidMoveError < StandardError
end

#REV: you should set your textmate program to use spaces instead of tabs
#so that they show up correctly when the code is viewed on github.

class Game

	attr_reader :board

#REV: could you have @current_player be equal to a HumanPlayer object
#instead of the key to access a HumanPlayer in the hash?
	def initialize
		@board = Board.new
		@players = {
			:red => HumanPlayer.new(:red),
			:black => HumanPlayer.new(:black)
		}
		@current_player = :red
	end


#REV: where do you check for game end?
	def play
		while true
			@players[@current_player].play_turn(@board)
			@current_player = (@current_player == :red) ? :black : :red
		end
		nil
	end

end

class HumanPlayer

	def initialize(color)
		@color = color
	end

#REV: play_turn needs to be split up into multiple methods; the while loop,
#begin-rescue-end blocks, and nested ifs are too hard to read.
	def play_turn(board)
		while true
			puts
			puts board.render
			puts

			puts "current player: #{@color}"

#REV: instead of having multiple begin-rescue-retry-end blocks, 
#you can raise errors from lower methods and catch them all 
#in a single, higher-level begin-rescue-retry-end.

		begin
			puts "which piece do you want to move? (e.g. 0,1)"
			from_pos = gets.chomp.split(",").map {|x| x.to_i}


			start_piece = board[from_pos]

			raise StandardError if start_piece.nil?
			raise StandardError if start_piece.color != @color
		rescue
			puts "you must move one of your own pieces"
			retry
		end

		begin
			puts "where do you want to move it to? you can enter multiple coordinates (e.g. 2,0 3,1 4,0)"

			multiple_moves = gets.chomp.split(" ").map do |coord|
				coord.split(",").map {|x| x.to_i}
			end

			if multiple_moves.length == 1

				start_piece.perform_moves(multiple_moves)
			end

			if multiple_moves.length > 1

				start_pos = start_piece.pos
				slide_moves_count = 0

				multiple_moves.each_with_index do |delta, index|
					if ((delta[0] - start_pos[0]).abs / (index + 1)) == 1
						slide_moves_count += 1
					end
				end

				if slide_moves_count == 0
					start_piece.perform_moves(multiple_moves)
				else
					puts "no slide moves allowed in a chain of multiple moves"
					raise
				end

			end
			
		rescue 
			#puts 'there was an error!!!!!!!!'
			retry
		end
			return

		end

	end

end

class Board
	attr_accessor :board
	def initialize
		make_starting_grid
	end

	def duplicate_board
		board2 = Board.new #board 2 is the duplicated board

		8.times do |row|
			8.times do |col|
				position = [row,col]

				if self[position].nil?
					board2[position] = nil
				else
					board2[position] = Piece.new(self[position].color, board2, self[position].pos, self[position].king)

				end
			end
		end

		board2
	end


	def make_starting_grid
		@board = Array.new(8) { Array.new(8) }

		[:red, :black].each do |color|
			fill_row_to_start(color)
		end
	end

	def fill_row_to_start(color)

		rows = (color == :red) ? [5,6,7] : [0,1,2]

		rows.each do |row|
			if row.even?
				8.times do |col|
					next if col.even?
					piece = Piece.new(color, self, [row,col])
				end
#REV: rows are always even or odd, so you can use else instead of elsif
			elsif row.odd?
				8.times do |col|
					next if col.odd?
					piece = Piece.new(color, self, [row,col])
				end
			end
		end

	end

#REV: Great little methods ([], within_bounds?, and empty?)

	def [](pos)
		raise "invalid pos" unless within_bounds?(pos)
		i,j = pos
		@board[i][j]
	end


	def within_bounds?(pos)
		pos.all? do |coord|
			(0...8).include?(coord)
		end
	end

	def empty?(pos)
		self[pos].nil?
	end

#REV: render could be refactored to make the loops and if statements simpler,
#or at least easier to read.
	def render

		pretty_board = @board.map.each_with_index do |row, i|
			row.map.each_with_index do |piece, j|
				if piece.nil?
					if (i+j).even?
						"   ".colorize(:background=>:light_white)
					else
						"   ".colorize(:background=>:light_cyan)
					end
				else
					if (i+j).even?
						piece.render.colorize(:background=>:light_white)
					else
						piece.render.colorize(:background=>:light_cyan)
					end
				end
			end.join
		end.join("\n")

		top_line = "   "
		(0..7).each {|x| top_line += x.to_s + "  "}
		top_line += "\n"
		top_line += pretty_board.split("\n").map.each_with_index do |line, i|
			i.to_s + " " + line
		end.join("\n")


	end	


	def []=(pos, piece)
		raise "invalid pos" unless within_bounds?(pos)
		i,j = pos
		@board[i][j] = piece
	end


end

class Piece

	attr_reader :color
	attr_accessor :pos, :king
	def initialize(color, board, pos, king=false)
		raise "invalid color" unless [:red, :black].include?(color)
		raise "invalid pos" unless board.within_bounds?(pos)
		@color, @board, @pos, @king = color, board, pos, king
		@board[pos] = self
	end

	def symbols
		if @king
			return {:red => ' ♛ '.colorize(:red), :black => ' ♛ '}
		end	
		{:red => ' ☻ '.colorize(:red), :black => ' ☻ '}
	end

	def render
		symbols[color]
	end

#REV: there seems to be a lot of repetition in slide_moves, jump_moves, and the
#king versions of the two methods. also, they're all large methods, so they
#could be split into more, smaller methods anyway.

	def slide_moves(to_pos)
		if @king
			return king_slide_moves(to_pos)
		end

		slide_moves = []

		forward_dir = (color == :red) ? -1 : 1
		i,j = pos
		single_increments = [[i + forward_dir, j + 1], [i + forward_dir, j - 1]]

		single_increments.each do |new_pos|
			next unless @board.within_bounds?(new_pos)
			if @board.empty?(new_pos)
				slide_moves << new_pos
			end
		end
		slide_moves

	end

	def jump_moves(to_pos)
		if @king
			return king_jump_moves(to_pos)
		end

		jump_moves = []

		forward_dir = (color == :red) ? -1 : 1
		i,j = pos
		single_increments = [[i + forward_dir, j + 1], [i + forward_dir, j - 1]]
		double_increments = [[i + (forward_dir * 2), j + 2], [i + (forward_dir * 2), j - 2]]
		single_increments.each_with_index do |intermediate_pos, index|
			next unless @board.within_bounds?(intermediate_pos)
			if !@board.empty?(intermediate_pos)
				if @board[intermediate_pos].color != color
					target_pos = double_increments[index]
					if @board.empty?(target_pos)
						jump_moves << target_pos
					end
				end
			end
		end
		jump_moves

	end

	def king_slide_moves(to_pos)
		slide_moves = []

		i,j = pos
		single_increments = [[i + 1, j + 1], [i + 1, j - 1], [i - 1, j + 1], [i - 1, j - 1]]

		single_increments.each do |new_pos|
			next unless @board.within_bounds?(new_pos)
			if @board.empty?(new_pos)
				slide_moves << new_pos
			end
		end
		slide_moves
	end

	def king_jump_moves(to_pos)
		jump_moves = []

		i,j = pos
		single_increments = [[i + 1, j + 1], [i + 1, j - 1], [i - 1, j + 1], [i - 1, j - 1]]
		double_increments = [[i + 2, j + 2], [i + 2, j - 2], [i - 2, j + 2], [i - 2, j - 2]]

		single_increments.each_with_index do |intermediate_pos, index|
			next unless @board.within_bounds?(intermediate_pos)
			if !@board.empty?(intermediate_pos) #if one away is not empty
				if @board[intermediate_pos].color != color #if one away is diff color
					target_pos = double_increments[index]
					next unless @board.within_bounds?(target_pos)
					if @board.empty?(target_pos)
						jump_moves << target_pos
					end
				end
			end
		end
		jump_moves
	end

	def king_me?
		king_row = (self.color == :red) ? 0 : 7

		if self.pos[0] == king_row
			self.king = true #make it into a king

		end

	end

#REV: the comments in perform_slide aren't needed
	def perform_slide(to_pos)
		if slide_moves(to_pos).include?(to_pos)
			#actually perform the move
			@board[to_pos] = self #put this piece in the new location

			@board[self.pos] = nil #make its original location empty
			self.pos = to_pos #make sure the piece has its new position in memory
			self.king_me? #make it a king if it reached the last row
			#puts @board.render #print out the board

		else
			#raise InvalidMoveError
			raise InvalidMoveError.new "one of those moves is invalid!"
		end
	end

	def perform_jump(to_pos)
		if jump_moves(to_pos).include?(to_pos)
			@board[to_pos] = self
			@board[self.pos] = nil #self.pos = from_pos
			eaten_pos = find_eaten_pos(self.pos, to_pos)
			@board[eaten_pos] = nil
			self.pos = to_pos
			self.king_me?
			#puts @board.render
		else
			raise InvalidMoveError.new "one of those moves is invalid!"
		end

	end

	def find_eaten_pos(from_pos, to_pos)
		dx = (to_pos[0] - from_pos[0]) / 2
		dy = (to_pos[1] - from_pos[1]) / 2
		eaten_pos = [to_pos[0] - dx, to_pos[1] - dy]
	end

#REV: the comment next to perform_moves! should be in a new line 
#(or could be deleted)
	def perform_moves!(move_sequence) #move sequence is an array of arrays and each array is the next new positition to move the piece to
		move_sequence.each do |next_pos|
			self.perform_jump_or_slide(next_pos)
			#continue doing this unless an error has arisen
		end
	end

	def perform_jump_or_slide(to_pos)
		if (self.pos[0] - to_pos[0]).abs == 1 #it's a slide move
			perform_slide(to_pos) #slide it
		elsif (self.pos[0] - to_pos[0]).abs > 1 #it's a jump move
			perform_jump(to_pos) #jump it
		end
	end

	def valid_move_seq?(move_sequence)
		dup_board = @board.duplicate_board
		dup_piece = Piece.new(self.color, dup_board, self.pos, self.king)
		begin
			dup_piece.perform_moves!(move_sequence)
			#if that does not raise an error
			return true
		rescue InvalidMoveError => e
			puts "error: #{e.message}"
			#revert to original board
			return false
		end
	end

	def perform_moves(move_sequence)
		if valid_move_seq?(move_sequence)
			perform_moves!(move_sequence)
		else
			raise "InvalidMoveError"

		end
	end


end