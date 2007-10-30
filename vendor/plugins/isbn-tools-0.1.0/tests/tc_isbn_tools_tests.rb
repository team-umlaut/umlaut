require "rubygems"
require "test/unit"
require "isbn/tools"

class TC_ISBN_Tools_Tests < Test::Unit::TestCase
	def setup
	end
	
	def teardown
	end

	def testing
		# ISBN 10 inputs
		isbn_orig_ok = "0-8436-1072-7"
		isbn_orig_bad = "0-8436-1072-x"
		# both values taken from: http://www.isbn.org/standards/home/isbn/transition.asp
		isbn_1_10 = "1-56619-909-3"
		isbn_1_13 = "978-1-56619-909-4"
		isbn_1_13b = "978-1-56619-909-x" # wrong check digit
		isbn_2_13 = "979-1-56619-909-3" # same as isbn_1_13 but altered with 979 and valid cksum
		isbn_3_10 = "2-930088-49-4" #unusually small (?) editor: good for hyphen testing!

		isbn_4_10 = "4413008480" # japanese ISBN (I think, ... At least, it validates.)

		isbn = ""

		# check that cleanup works
		assert_equal(true, "0843610727".eql?(ISBN_Tools.cleanup(isbn_orig_ok)))
		# and does not alter provided argument
		assert_equal("0-8436-1072-7",isbn_orig_ok)
		# test that cleanup! does alter the original string
		isbn.replace(isbn_orig_ok)
		ISBN_Tools.cleanup!(isbn)
		assert_equal("0843610727", isbn)
		# grrr .. Nte to self: make sure that isbn was not setup as a simple reference to  
		#			isbn_orig_ok otherwise it will also be altered. Use replace as above.
		assert_equal("0-8436-1072-7",isbn_orig_ok)
		# test that X is upper cased (even on bad numbers)
		assert_equal(true, "084361072X".eql?(ISBN_Tools.cleanup(isbn_orig_bad)))

		# test that it is a valid isbn 10 number
		assert_equal(true, ISBN_Tools.is_valid_isbn10?(isbn_orig_ok))
		assert_equal(true, ISBN_Tools.is_valid_isbn10?(isbn_4_10))
		# test that it is NOT a valid isbn 10 number
		assert_equal(false, ISBN_Tools.is_valid_isbn10?(isbn_orig_bad))
		assert_equal(false, ISBN_Tools.is_valid_isbn10?(isbn_1_13))
		# same as the two tests above but via the generic is_valid? method. Must have identical result.
		assert_equal(true, ISBN_Tools.is_valid?(isbn_orig_ok))
		assert_equal(false, ISBN_Tools.is_valid?(isbn_orig_bad))
		# test that it is NOT a valid isbn 13 number
		assert_equal(false, ISBN_Tools.is_valid_isbn13?(isbn_orig_bad))
		# test that it is a valid isbn 13 number
		assert_equal(true, ISBN_Tools.is_valid_isbn13?(isbn_1_13))
		# same as the two tests above but via the generic is_valid? method. Must have identical result.
		assert_equal(true, ISBN_Tools.is_valid?(isbn_1_13))
		assert_equal(false, ISBN_Tools.is_valid?(isbn_1_13b))
		# test that check digit is indeed 7
		assert_equal("7",ISBN_Tools.compute_isbn10_check_digit(isbn_orig_ok))
		# test must also succeed on isbn_orig_bad since only the check digit changes
		# 	and it must not be considered in the computation
		assert_equal("7",ISBN_Tools.compute_isbn10_check_digit(isbn_orig_bad))
		# test check digit of isbn 13 number. Must be 4
		assert_equal("4",ISBN_Tools.compute_isbn13_check_digit(isbn_1_13))
		# test must also succeed on isbn_orig_bad since only the check digit changes
		# 	and it must not be considered in the computation
		assert_equal("4",ISBN_Tools.compute_isbn13_check_digit(isbn_1_13b))
		# test the wrapper, once for ISBN10 and once for ISBN13
		assert_equal("7",ISBN_Tools.compute_check_digit(isbn_orig_ok))
		assert_equal("4",ISBN_Tools.compute_check_digit(isbn_1_13))

		# verify hyphenation from cleanup version
		assert_equal(isbn_orig_ok, ISBN_Tools.hyphenate_isbn10(isbn_orig_ok))
		assert_equal(isbn_1_10, ISBN_Tools.hyphenate_isbn10(isbn_1_10))
		assert_equal(isbn_3_10, ISBN_Tools.hyphenate_isbn10(isbn_3_10))
		assert_equal(isbn_3_10, ISBN_Tools.hyphenate_isbn10(isbn_3_10))
		# fail on hyphenating a non group 0/1/2 ISBN
		assert_equal(nil, ISBN_Tools.hyphenate_isbn10(isbn_4_10))
		# fail on hyphenating an invalid isbn
		assert_equal(nil, ISBN_Tools.hyphenate_isbn10(isbn_orig_bad))
		# on isbn 13
		assert_equal(isbn_1_13,ISBN_Tools.hyphenate_isbn13(isbn_1_13))
		# same result with cleanup up one
		assert_equal(isbn_1_13,ISBN_Tools.hyphenate_isbn13(ISBN_Tools.cleanup(isbn_1_13)))
		# check the generic method
		assert_equal(isbn_1_13,ISBN_Tools.hyphenate(isbn_1_13))
		assert_equal(isbn_1_10, ISBN_Tools.hyphenate(isbn_1_10))
		assert_equal(nil, ISBN_Tools.hyphenate(isbn_4_10))
		# check that hyphenate! alters the argument
		isbn.replace(isbn_1_10)
		ISBN_Tools.cleanup!(isbn)
		assert_equal(isbn_1_10,ISBN_Tools.hyphenate!(isbn))
		assert_equal(isbn,isbn_1_10)

		# test conversion from 10 to 13
		assert_equal(ISBN_Tools.cleanup(isbn_1_13), ISBN_Tools.isbn10_to_isbn13(isbn_1_10))
		# test conversion from 13 to 10
		assert_equal(ISBN_Tools.cleanup(isbn_1_10), ISBN_Tools.isbn13_to_isbn10(isbn_1_13))
		# test illegal conversion from 13 to 10 (should return nil because of the 979)
		assert_equal(nil, ISBN_Tools.isbn13_to_isbn10(isbn_2_13))

	end
end

require 'test/unit/ui/console/testrunner'
Test::Unit::UI::Console::TestRunner.run(TC_ISBN_Tools_Tests)
