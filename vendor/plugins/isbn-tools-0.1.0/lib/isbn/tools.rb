#--
# Copyright 2006, Thierry Godfroid
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# * The name of the author may not be used to endorse or promote products derived
# 	from this software without specific prior written permission.
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A 
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

# This module provides all the methods of the ISBN-Tools library.
# Methods have no state but the library reads the file data/ranges.dat
# and fills up the RNG hash when loaded.
module ISBN_Tools
	# Supported groups and associated ranges. Data is read from data/ranges.dat
	# (provided in gem) at module load.
	RNG = {}

	File.open(File.join(File.dirname(__FILE__), "../../data/ranges.dat")) do |file|
		file.each do |line|
			line.chomp!
			break if line.empty?
			ar_line = line.split(/,/)
			ndx = ar_line.delete_at(0)
			RNG[ndx] = []
			ar_line.each { |item| 
				r = item.split(/\.\./)
				RNG[ndx].push(Range.new(r[0],r[1]))
			}
		end
	end

	# Clear all useless characters from an ISBN number and upcase the 'X' sign when
	# present.  Also does the basic check that 'X' must be the last sign of the number,
	# if present.  Returns nil if provided string is nil or X is not at the last position.
	#
	# No length check is done: no matter what string is passed in, all characters that
	# not in the range [0-9xX] are removed.
	def ISBN_Tools.cleanup(isbn_)
		isbn_.gsub(/[^0-9xX]/,'').gsub(/x/,'X') unless isbn_.nil? or isbn_.scan(/([xX])/).length > 1
	end
	
	# Same as cleanup but alters the argument.
	def ISBN_Tools.cleanup!(isbn_)
		isbn_.replace(cleanup(isbn_))
	end

	# Check that the value is a valid ISBN-10 number. Returns true if it is, false otherwise.
	# The method will check that the number is exactly 10 digits long and that the tenth digit is
	# the correct checksum for the number.
	def ISBN_Tools.is_valid_isbn10?(isbn_)
		isbn = cleanup(isbn_)
		return false if isbn.nil? or isbn.match(/^[0-9]{9}[0-9X]$/).nil?
		sum = 0;
		0.upto(9) { |ndx| sum += (isbn[ndx]!= 88 ? isbn[ndx].chr.to_i : 10) * (10-ndx) } # 88 is ascii of X
		sum % 11 == 0
	end

	# Check that the value is a valid ISBN-13 number. Returns true if it is, false otherwise.
	# The method will check that the number is exactly 13 digits long and that the thirteenth digit is
	# the correct checksum for the number.
	def ISBN_Tools.is_valid_isbn13?(isbn_)
		isbn = cleanup(isbn_)
		return false if isbn.nil? or isbn.length!=13 or isbn.match(/^97[8|9][0-9]{10}$/).nil?
		sum = 0
		0.upto(12) { |ndx| sum += isbn[ndx].chr.to_i * (ndx % 2 == 0 ? 1 : 3) }
		sum.remainder(10) == 0
	end

	# Check that an ISBN is valid or not. Returns true if is, false otherwise.  This method will
	# first call is_valid_isbn10() and, on failure, try is_valid_isbn13().  Returns true if it is
	# a valid number, false otherwise.
	# This method is handy if you don't want to be bothered by checking the length of your
	# isbn before checking its validity. It is a bit slower since cleanup will be called twice.
	def ISBN_Tools.is_valid?(isbn_)
		is_valid_isbn10?(isbn_) || is_valid_isbn13?(isbn_)
	end

	# Computes the check digit of an ISBN-10 number.  It will ignore the tenth sign if present
	# and accepts a number with only 9 digits.  Returns the checksum digit or nil.  Please note
	# that the checksum digit of an ISBN-10 may be the character 'X'.
	def ISBN_Tools.compute_isbn10_check_digit(isbn_)
		isbn = cleanup(isbn_)
		return nil if isbn.nil? or isbn.length > 10 or isbn.length < 9
		sum = 0; 
		0.upto(8) { |ndx| sum += isbn[ndx].chr.to_i * (10-ndx) }
		(11-sum) % 11 == 10 ? "X" : ((11-sum) % 11).to_s
	end

	# Computes the check digit of an ISBN-13 number.  It will ignore the thirteenth sign if present
	# and accepts a number with only 12 digits.  Returns the checksum digit or nil.  Please note
	# that the checksum digit of an ISBN-13 is always in the range [0-9].
	def ISBN_Tools.compute_isbn13_check_digit(isbn_)
		isbn = cleanup(isbn_)
		return nil if isbn.nil? or isbn.length > 13 or isbn.length < 12
		sum = 0
		0.upto(11) { |ndx| sum += isbn[ndx].chr.to_i * (ndx % 2 == 0 ? 1 : 3) }
		(10-sum.remainder(10)) == 10 ? "0" : (10-sum.remainder(10)).to_s
	end

	# Compute the check digit of an ISBN number. Try as an ISBN-10 number
	# first, and if it failed, as an ISBN-13 number. Returns the check digit or
	# nil if a processing error occured.
	# This method is a helper for compute_isbn10_check_digit and
	# compute_isbn13_check_digit.
	def ISBN_Tools.compute_check_digit(isbn_)
			compute_isbn10_check_digit(isbn_) || compute_isbn13_check_digit(isbn_)
	end

	# Convert an ISBN-10 number to its equivalent ISBN-13 number.  Returns the converted number or nil
	# if the provided ISBN-10 number is nil or non valid.
	def ISBN_Tools.isbn10_to_isbn13(isbn_)
		isbn = cleanup(isbn_)
		"978" + isbn[0..8] + compute_isbn13_check_digit("978" + isbn[0..8]) unless isbn.nil? or ! is_valid_isbn10?(isbn)
	end

	# Convert an ISBN-13 number to its equivalent ISBN-10 number.  Returns the converted number or nil
	# if the provided ISBN-13 number is nil or non valid. Please note that only ISBN-13 numbers starting
	# with 978 can be converted.
	def ISBN_Tools.isbn13_to_isbn10(isbn_)
		isbn = cleanup(isbn_)
		isbn[3..11] +  compute_isbn10_check_digit(isbn[3..11]) unless isbn.nil? or ! is_valid_isbn13?(isbn) or ! isbn_.match(/^978.*/)
	end

	# Hyphenate a valid ISBN-10 number.  Returns nil if the number is invalid or if the group range is 
	# unknown.  Works only for groups 0,1 and 2.
	def ISBN_Tools.hyphenate_isbn10(isbn_)
		isbn = cleanup(isbn_)
		group = isbn[0..0]
		if RNG.has_key?(group) and is_valid_isbn10?(isbn)
			RNG[group].each { |r| return isbn.sub(Regexp.new("(.{1})(.{#{r.last.length}})(.{#{8-r.last.length}})(.)"),'\1-\2-\3-\4') if r.member?(isbn[1..r.last.length]) }
		end
	end

	# Hyphenate a valid ISBN-13 number.  Returns nil if the number is invalid or if the group range is 
	# unknown.   Works only for groups 0,1 and 2.
	def ISBN_Tools.hyphenate_isbn13(isbn_)
		isbn = cleanup(isbn_)
		if is_valid_isbn13?(isbn)
			group = isbn[3..3]
			if RNG.has_key?(group)
				RNG[group].each { |r| return isbn.sub(Regexp.new("(.{3})(.{1})(.{#{r.last.length}})(.{#{8-r.last.length}})(.)"),'\1-\2-\3-\4-\5') if r.member?(isbn[1..r.last.length]) }
			end
		end
	end

	# This method takes an ISBN then tries to hyphenate it as an ISBN 10 then an ISBN 13.  A bit slower
	# than calling the right one directly but saves you the length checking. Returns an hyphenated value
	# or nil.
	def ISBN_Tools.hyphenate(isbn_)
		hyphenate_isbn10(isbn_) || hyphenate_isbn13(isbn_)
	end

	# Same as hyphenate() but alters the argument.
	def ISBN_Tools.hyphenate!(isbn_)
		isbn_.replace(hyphenate(isbn_))
	end

end
