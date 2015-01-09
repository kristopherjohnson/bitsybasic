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

#ifndef __finchbasic__parse__
#define __finchbasic__parse__

#include "InterpreterEngine.h"


namespace finchlib_cpp
{
class InputPos;


/// Result from an attempt to parse an element
///
/// If `success()` is true, then call `value()` and
/// `nextPos()` to get the parsed value and the position
/// following the parsed element.
///
/// `ParseResult<T>` is an abstract class.  Concrete subclasses
/// are `NotParsed<T>` and `Parsed<T>`.
template <typename T>
class ParseResult
{
public:
    /// Return true if parse was successful, false if not.
    virtual bool wasParsed() const = 0;

    // Only call these if success() returns true
    virtual const T *value() const = 0;
    virtual const InputPos *nextPos() const = 0;
};

/// Concrete subclass of ParseResult<T> for a failed parse attempt.
template <typename T>
class NotParsed : public ParseResult<T>
{
public:
    virtual bool wasParsed() const { return false; }
    virtual const T *value() const { return nullptr; }
    virtual const InputPos *nextPos() const { return nullptr; }
};

// Parsed is defined after InputPos
template <typename T>
struct Parsed;

// Parse is defined after InputPos

/// Container for a ParseResult
template <typename T>
class Parse
{
private:
    std::shared_ptr<ParseResult<T> > result;

public:
    Parse(std::shared_ptr<ParseResult<T> > res)
        : result(res)
    {
    }

    bool wasParsed() const { return result->wasParsed(); }

    // It is not valid to call value() or nextPos() if wasParsed()
    // is not true. The result would be an access violation.
    const T &value() const { return *result->value(); }
    const InputPos &nextPos() const { return *result->nextPos(); }
};


#pragma mark - InputPos

/// Current position on a line of input
///
/// This encapsulates the concept of an index into a character array.
/// It provides some convenient methods/properties used by the
/// parsing code in `InterpreterEngine`.
struct InputPos
{
    const InputLine &input;
    size_t index;

    InputPos(const InputLine &line, size_t n)
        : input(line)
        , index(n)
    {
    }

    InputPos(const InputPos &copy)
        : input(copy.input)
        , index(copy.index)
    {
    }

    InputPos &operator=(const InputPos &copy)
    {
        // Assignment is only valid for positions in the same input line
        assert(this->input == copy.input);
        index = copy.index;
        return *this;
    }

    /// Return the character at this position
    Char at() const
    {
        assert(!isAtEndOfLine());
        return input.at(index);
    }

    /// Return true if there are no non-space characters at or following the
    /// specified index in the specified line
    bool isRemainingLineEmpty() const
    {
        return afterSpaces().index == input.size();
    }

    /// Return number of characters following this position, including the character at this position)
    size_t remainingCount() const
    {
        return input.size() - index;
    }

    /// Return remaining characters on line, including the character at this position
    std::vector<Char> remainingChars() const
    {
        const auto count = input.size();
        if (index >= count)
        {
            return {};
        }

        // TODO: check for a C++ Standard Library std::function to do this
        std::vector<Char> result;
        for (auto i = index; i < count; ++i)
        {
            result.push_back(input.at(i));
        }
        return result;
    }

    /// Return true if this position is at the end of the line
    bool isAtEndOfLine() const
    {
        return index >= input.size();
    }

    /// Return the next input position
    InputPos next() const
    {
        return {input, index + 1};
    }

    /// Return the position at the end of the line
    InputPos endOfLine() const
    {
        return {input, input.size()};
    }

    /// Return position of first non-space character at or after this position
    InputPos afterSpaces() const
    {
        auto i = index;
        const auto count = input.size();
        while (i < count && input.at(i) == ' ')
        {
            ++i;
        }
        return {input, i};
    }

    // The parse() methods take a starting position and a sequence
    // of "parsing std::functions" to apply in order.
    //
    // Each parsing std::function takes an `InputPos` and returns a
    // `Parse<T>>`, where `T` is the type of data parsed.
    //
    // `parse()` returns a std::tuple containing all the parsed elements
    // and the following `InputPos`, or returns `nullptr` if any
    // of the parsing std::functions fail.
    //
    // This allows us to write pattern-matching-like parsing code like this:
    //
    //     // Try to parse "LET var = expr"
    //     std::unique_ptr<std::tuple<string, Lvalue, string, Expression, InputPos>> t
    //         = pos.parse<string, Lvalue, string, Expression>
    //             (lit("LET"), variable, lit("="), expression);
    //     if (t != nullptr)
    //     {
    //         // do something with the five-element std::tuple *t
    //         // ...
    //     }
    //
    // which is equivalent to this:
    //
    //     const auto keyword = lit("LET")(pos);
    //     if (keyword.wasParsed()) {
    //         const auto varname = variable(keyword.nextPos());
    //         if (varname) {
    //             const auto eq = lit("=")(varname.nextPos());
    //             if (varname.wasParsed()) {
    //                 const auto expr = expression(eq.nextPos());
    //                 if (expr) {
    //                     // do something with keyword, varname, eq, and expr
    //                 }
    //             }
    //         }
    //     }
    //
    // where `lit(String)`, `variable`, and `expression` are
    // std::functions that take an `InputPos` and return a Parse<T>.

    template <typename A>
    std::unique_ptr<std::tuple<A, InputPos> > parse(
        std::function<Parse<A>(const InputPos &pos)> a)
        const
    {
        const auto aP = a(*this);
        if (aP.wasParsed())
        {
            return std::unique_ptr<std::tuple<A, InputPos> >(
                new std::tuple<A, InputPos>(aP.value(), aP.nextPos()));
        }

        return nullptr;
    }

    template <typename A, typename B>
    std::unique_ptr<std::tuple<A, B, InputPos> > parse(
        std::function<Parse<A>(const InputPos &pos)> a,
        std::function<Parse<B>(const InputPos &pos)> b)
        const
    {
        const Parse<A> aP = a(*this);
        if (aP.wasParsed())
        {
            const Parse<B> bP = b(aP.nextPos());
            if (bP.wasParsed())
            {
                return std::unique_ptr<std::tuple<A, B, InputPos> >(new std::tuple<A, B, InputPos>(
                    aP.value(), bP.value(), bP.nextPos()));
            }
        }

        return nullptr;
    }

    template <typename A, typename B, typename C>
    std::unique_ptr<std::tuple<A, B, C, InputPos> > parse(
        std::function<Parse<A>(const InputPos &pos)> a,
        std::function<Parse<B>(const InputPos &pos)> b,
        std::function<Parse<C>(const InputPos &pos)> c)
        const
    {
        const Parse<A> aP = a(*this);
        if (aP.wasParsed())
        {
            const Parse<B> bP = b(aP.nextPos());
            if (bP.wasParsed())
            {
                const Parse<C> cP = c(bP.nextPos());
                if (cP.wasParsed())
                {
                    return std::unique_ptr<std::tuple<A, B, C, InputPos> >(new std::tuple<A, B, C, InputPos>(
                        aP.value(), bP.value(), cP.value(), cP.nextPos()));
                }
            }
        }

        return nullptr;
    }

    template <typename A, typename B, typename C, typename D>
    std::unique_ptr<std::tuple<A, B, C, D, InputPos> > parse(
        std::function<Parse<A>(const InputPos &pos)> a,
        std::function<Parse<B>(const InputPos &pos)> b,
        std::function<Parse<C>(const InputPos &pos)> c,
        std::function<Parse<D>(const InputPos &pos)> d)
        const
    {
        const Parse<A> aP = a(*this);
        if (aP.wasParsed())
        {
            const Parse<B> bP = b(aP.nextPos());
            if (bP.wasParsed())
            {
                const Parse<C> cP = c(bP.nextPos());
                if (cP.wasParsed())
                {
                    const Parse<D> dP = d(cP.nextPos());
                    if (dP.wasParsed())
                    {
                        return std::unique_ptr<std::tuple<A, B, C, D, InputPos> >(new std::tuple<A, B, C, D, InputPos>(
                            aP.value(), bP.value(), cP.value(), dP.value(), dP.nextPos()));
                    }
                }
            }
        }

        return nullptr;
    }

    template <typename A, typename B, typename C, typename D, typename E>
    std::unique_ptr<std::tuple<A, B, C, D, E, InputPos> > parse(
        std::function<Parse<A>(const InputPos &pos)> a,
        std::function<Parse<B>(const InputPos &pos)> b,
        std::function<Parse<C>(const InputPos &pos)> c,
        std::function<Parse<D>(const InputPos &pos)> d,
        std::function<Parse<E>(const InputPos &pos)> e)
        const
    {
        const Parse<A> aP = a(*this);
        if (aP.wasParsed())
        {
            const Parse<B> bP = b(aP.nextPos());
            if (bP.wasParsed())
            {
                const Parse<C> cP = c(bP.nextPos());
                if (cP.wasParsed())
                {
                    const Parse<D> dP = d(cP.nextPos());
                    if (dP.wasParsed())
                    {
                        const Parse<E> eP = e(dP.nextPos());
                        if (eP.wasParsed())
                        {
                            return std::unique_ptr<std::tuple<A, B, C, D, E, InputPos> >(new std::tuple<A, B, C, D, E, InputPos>(
                                aP.value(), bP.value(), cP.value(), dP.value(), eP.value(), eP.nextPos()));
                        }
                    }
                }
            }
        }

        return nullptr;
    }

    template <typename A, typename B, typename C, typename D, typename E, typename F>
    std::shared_ptr<std::tuple<A, B, C, D, E, F, InputPos> > parse(
        std::function<Parse<A>(const InputPos &pos)> a,
        std::function<Parse<B>(const InputPos &pos)> b,
        std::function<Parse<C>(const InputPos &pos)> c,
        std::function<Parse<D>(const InputPos &pos)> d,
        std::function<Parse<E>(const InputPos &pos)> e,
        std::function<Parse<F>(const InputPos &pos)> f)
        const
    {
        const Parse<A> aP = a(*this);
        if (aP.wasParsed())
        {
            const Parse<B> bP = b(aP.nextPos());
            if (bP.wasParsed())
            {
                const Parse<C> cP = c(bP.nextPos());
                if (cP.wasParsed())
                {
                    const Parse<D> dP = d(cP.nextPos());
                    if (dP.wasParsed())
                    {
                        const Parse<E> eP = e(dP.nextPos());
                        if (eP.wasParsed())
                        {
                            const Parse<F> fP = f(eP.nextPos());
                            if (fP.wasParsed())
                            {
                                return std::unique_ptr<std::tuple<A, B, C, D, E, F, InputPos> >(new std::tuple<A, B, C, D, E, F, InputPos>(
                                    aP.value(), bP.value(), cP.value(), dP.value(), eP.value(), fP.value(), fP.nextPos()));
                            }
                        }
                    }
                }
            }
        }

        return nullptr;
    }
};

/// Concrete subclass of ParseResult<T> for a successful parse operation
template <typename T>
class Parsed : public ParseResult<T>
{
private:
    T value_;
    InputPos nextPos_;

public:
    Parsed(const T &v, const InputPos &next)
        : value_{v}
        , nextPos_{next}
    {
    }

    virtual bool wasParsed() const { return true; }
    virtual const T *value() const { return &value_; }
    virtual const InputPos *nextPos() const { return &nextPos_; }
};

/// Return a newly constructed Parse object representing a failure
template <class T>
static Parse<T> failedParse()
{
    ParseResult<T> *p = new NotParsed<T>();
    return Parse<T>{std::shared_ptr<ParseResult<T> >{p}};
}

/// Return a newly constructed Parse object representing success
template <class T>
static Parse<T> successfulParse(const T &v, const InputPos &next)
{
    ParseResult<T> *p = new Parsed<T>(v, next);
    return Parse<T>{std::shared_ptr<ParseResult<T> >{p}};
}

/// Determine whether character is a digit
inline bool isDigitChar(Char c)
{
    return '0' <= c && c <= '9';
}

/// Parse a statement
///
/// Returns a parsed statement and position of character
/// following the end of the parsed statement, or nil
/// if there is no valid statement.
Parse<Statement> statement(const InputPos &pos);

/// Parse user entry for INPUT
///
/// Return parsed number and following position if successful.
///
/// Accepts entry of a number with optional leading sign (+|-), or a variable name.
Parse<Number> inputExpression(const InputPos &pos, InterpreterEngine &engine);

/// Attempt to read an unsigned number from input.  If successful, returns
/// parsed number and position of next input character.  If not, returns nil.
Parse<Number> numberLiteral(const InputPos &pos);

/// Determine whether the remainder of the line starts with a specified sequence of characters.
///
/// If true, returns position of the character following the matched string. If false, returns nil.
///
/// Matching is case-insensitive. Spaces in the input are ignored.
Parse<std::string> literal(std::string s, const InputPos &pos);

} // namespace finchlib_cpp

#endif /* defined(__finchbasic__parse__) */
