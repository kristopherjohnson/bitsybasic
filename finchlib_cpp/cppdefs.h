/*
 Copyright (c) 2015 Kristopher Johnson

 Permission is hereby granted, free of charge, to any person obtaining
 a copy of this software and associated documentation files (the
 "Software"), to deal in the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to
 permit persons to whom the Software is furnished to do so, subject to
 the following conditions:

 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#ifndef finchlib_cpp_cppdefs_h
#define finchlib_cpp_cppdefs_h

#include <cctype>
#include <functional>
#include <map>
#include <memory>
#include <sstream>
#include <string>
#include <tuple>
#include <vector>

namespace finchlib_cpp
{

// Bring types and functions from the std namespace into this namespace
using std::equal_to;
using std::function;
using std::greater;
using std::greater_equal;
using std::initializer_list;
using std::less;
using std::less_equal;
using std::make_shared;
using std::make_unique;
using std::map;
using std::minus;
using std::multiplies;
using std::not_equal_to;
using std::numeric_limits;
using std::ostringstream;
using std::plus;
using std::string;
using std::pair;
using std::toupper;
using std::tuple;

// Use "ptr" as abbreviation for "std::shared_ptr"
template <typename T>
using ptr = std::shared_ptr<T>;

// Use "uptr" as abbreviation for "std::unique_ptr"
template <typename T>
using uptr = std::unique_ptr<T>;

// Use "vec" as abbreviation for "std::vector"
template <typename T>
using vec = std::vector<T>;
}

#endif
