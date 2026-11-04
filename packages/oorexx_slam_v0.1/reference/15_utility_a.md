# the classes for time and for activities

these facts are from the first part of the reference about the classes of use: the classes for time, and the classes for activities that run at the same time.

## words i add

datetime: the name of a class; a datetime object is a time on a day
timespan: the name of a class; a timespan object is a length of time
interval: a length of time between two times
weeks: more than one week
months: more than one month
leap: a leap year is a year with one more day than the other years
future: the time after now
orderable: the name of a mixin class; with it, a class has all the methods that compare two objects to put them in order
iso: the name of a set of rules for the way to write a date and a time
semaphore: an object that activities use to wait for the other activities
east: the place where a day starts before it starts at the place of utc
west: the place where a day starts after it starts at the place of utc

## the datetime class

```
.DateTime
```
an object of this class is a time on a day.
the first time it can be is the start of the first day of the year 1.
the last time it can be is the last of the microseconds of the last day of the year 9999.
this class has methods to give a date or a time in many ways, and to add and subtract times.
this class does not know about a minute with one more second, as at the end of the year 2016 in utc.
this class inherits the mixin classes orderable and comparable.
so you can compare two datetime objects with each compare operator.
the string value of a datetime object is in the iso way: four digits of the year, a dash, two digits of the month, a dash, two digits of the day, the first letter of the word time in upper, two digits each of the hours, the minutes, and the seconds with a colon between them, a period, and six digits of microseconds.
the string method and the makestring method give this string value.
many methods of this class have an optional offset argument.
the offset argument is the offset from utc, in minutes.
the offset must be a whole number from -900 to 900, or a timespan object of the same value.
the default offset is the offset of the system now.

```
.DateTime~minDate
```
this method is a class method.
this method gives a datetime object for the first time this class can have: the start of the first day of the year 1.

```
.DateTime~maxDate
```
this method is a class method.
this method gives a datetime object for the last time this class can have: the last of the microseconds of the last day of the year 9999.

```
.DateTime~today([offset])
```
today: this day
this method is a class method.
this method gives a datetime object for this day, with the time 00:00:00.000000.
the offset argument is optional; it is the offset from utc, in minutes.
the offset must be a whole number from -900 to 900, or a timespan object of the same value.
the default offset is the offset of the system now.

```
.DateTime~fromBaseDate(date [,offset])
```
this method is a class method.
this method gives a new datetime object from the date argument.
the date argument is a string in the way that the date builtin function gives with the base option: the count of whole days from the first day of the year 1.
the time of the new object is 00:00:00.000000.
the offset argument is optional; it is the offset from utc, in minutes.
the offset must be a whole number from -900 to 900, or a timespan object of the same value.
the default offset is the offset of the system now.

```
.DateTime~fromEuropeanDate(date [,separator] [,offset])
```
this method is a class method.
this method gives a new datetime object from the date argument.
the date argument is a string of two digits of the day, two digits of the month, and the last two digits of the year, with a separator between them.
the time of the new object is 00:00:00.000000.
the separator argument is optional; it is the character between the parts of the date argument.
the separator must be one character or an empty string.
the default separator is a slash.
the offset argument is optional; it is the offset from utc, in minutes.
the offset must be a whole number from -900 to 900, or a timespan object of the same value.
the default offset is the offset of the system now.

```
.DateTime~fromNormalDate(date [,separator] [,offset])
```
this method is a class method.
this method gives a new datetime object from the date argument.
the date argument is a string in the way that the date builtin function gives with the normal option: the day, the first three letters of the english name of the month, and the four digits of the year, with a separator between them.
the time of the new object is 00:00:00.000000.
the separator argument is optional; it is the character between the parts of the date argument.
the separator must be one character or an empty string.
the default separator is a blank.
the offset argument is optional; it is the offset from utc, in minutes.
the offset must be a whole number from -900 to 900, or a timespan object of the same value.
the default offset is the offset of the system now.

```
.DateTime~fromOrderedDate(date [,separator] [,offset])
```
this method is a class method.
this method gives a new datetime object from the date argument.
the date argument is a string in the way that the date builtin function gives with the ordered option: the last two digits of the year, two digits of the month, and two digits of the day, with a separator between them.
the time of the new object is 00:00:00.000000.
the separator argument is optional; it is the character between the parts of the date argument.
the separator must be one character or an empty string.
the default separator is a slash.
the offset argument is optional; it is the offset from utc, in minutes.
the offset must be a whole number from -900 to 900, or a timespan object of the same value.
the default offset is the offset of the system now.

```
.DateTime~fromOrdinalDate(date [,offset])
```
this method is a class method.
this method gives a new datetime object from the date argument.
the date argument is a string of four digits of the year, then three digits of the number of the day in that year.
the date argument can have a dash between the year and the day, or no dash.
the number of the day is from 1 to the count of days in that year: 365 or 366.
the year and the day must have zero digits at the left as they need.
the time of the new object is 00:00:00.000000.
the offset argument is optional; it is the offset from utc, in minutes.
the offset must be a whole number from -900 to 900, or a timespan object of the same value.
the default offset is the offset of the system now.
an other method of this class gives a string in the way of the date argument.
the code:
```rexx
say .DateTime~fromOrdinalDate("2020-041")
```
the result:
```
2020-02-10T00:00:00.000000
```
the reference says:
```
2020-02-10T00:00:00.000000
```

```
.DateTime~fromStandardDate(date [,separator] [,offset])
```
this method is a class method.
this method gives a new datetime object from the date argument.
the date argument is a string in the way that the date builtin function gives with the standard option: four digits of the year, two digits of the month, and two digits of the day, with a separator between them.
the time of the new object is 00:00:00.000000.
the separator argument is optional; it is the character between the parts of the date argument.
the separator must be one character or an empty string.
the default separator is an empty string.
the offset argument is optional; it is the offset from utc, in minutes.
the offset must be a whole number from -900 to 900, or a timespan object of the same value.
the default offset is the offset of the system now.

```
.DateTime~fromUsaDate(date [,separator] [,offset])
```
this method is a class method.
this method gives a new datetime object from the date argument.
the date argument is a string of two digits of the month, two digits of the day, and the last two digits of the year, with a separator between them.
the time of the new object is 00:00:00.000000.
the separator argument is optional; it is the character between the parts of the date argument.
the separator must be one character or an empty string.
the default separator is a slash.
the offset argument is optional; it is the offset from utc, in minutes.
the offset must be a whole number from -900 to 900, or a timespan object of the same value.
the default offset is the offset of the system now.

```
.DateTime~fromWeekNumberDate(date [,offset])
```
this method is a class method.
this method gives a new datetime object from the date argument.
the date argument is a string of four digits of the year, the first letter of the word week in upper, two digits of the number of the week in the year in the iso way, and one digit of the day in that week.
the date argument can have a dash after the year and after the week, or no dash.
the number of the week is from 1 to the count of iso weeks in that year: 52 or 53.
the year and the week must have zero digits at the left as they need.
the day is from 1 to 7: 1 is the first day of the week in the iso way, and 7 is the last day.
the time of the new object is 00:00:00.000000.
the offset argument is optional; it is the offset from utc, in minutes.
the offset must be a whole number from -900 to 900, or a timespan object of the same value.
the default offset is the offset of the system now.
the code:
```rexx
say .DateTime~fromWeekNumberDate("2020-W07-1")
```
the result:
```
2020-02-10T00:00:00.000000
```
the reference says:
```
2020-02-10T00:00:00.000000
```

```
.DateTime~fromNormalTime(time [,offset])
```
this method is a class method.
this method gives a new datetime object from the time argument.
the time argument is a string in the way that the time builtin function gives with the normal option: two digits each of the hours, the minutes, and the seconds, with a colon between them.
the day of the new object is the first day of the year 1.
the offset argument is optional; it is the offset from utc, in minutes.
the offset must be a whole number from -900 to 900, or a timespan object of the same value.
the default offset is the offset of the system now.

```
.DateTime~fromCivilTime(time [,offset])
```
this method is a class method.
this method gives a new datetime object from the time argument.
the time argument is a string of the hours from 1 to 12, a colon, two digits of the minutes, and then two letters that say if the time is in the first part of the day or in the rest of the day.
the day of the new object is the first day of the year 1.
the offset argument is optional; it is the offset from utc, in minutes.
the offset must be a whole number from -900 to 900, or a timespan object of the same value.
the default offset is the offset of the system now.

```
.DateTime~fromLongTime(time [,offset])
```
this method is a class method.
this method gives a new datetime object from the time argument.
the time argument is a string in the way that the time builtin function gives with the long option: two digits each of the hours, the minutes, and the seconds with a colon between them, a period, and six digits of microseconds.
the day of the new object is the first day of the year 1.
the offset argument is optional; it is the offset from utc, in minutes.
the offset must be a whole number from -900 to 900, or a timespan object of the same value.
the default offset is the offset of the system now.

```
.DateTime~fromTicks(time [,offset])
```
ticks: the name of an option of the date and time builtin functions; with it, they give a count of seconds
this method is a class method.
this method gives a new datetime object from the time argument.
the time argument is a string in the way that the date or time builtin function gives with the ticks option.
the offset argument is optional; it is the offset from utc, in minutes.
the offset must be a whole number from -900 to 900, or a timespan object of the same value.
the default offset is the offset of the system now.

```
.DateTime~fromIsoDate(date [,offset])
```
this method is a class method.
this method gives a new datetime object from the date argument.
the date argument is a string in the iso way: the way of the string value of a datetime object.
the string method gives a string in this way.
the offset argument is optional; it is the offset from utc, in minutes.
the offset must be a whole number from -900 to 900, or a timespan object of the same value.
the default offset is the offset of the system now.

```
.DateTime~fromUtcIsoDate(date)
```
this method is a class method.
this method gives a new datetime object from the date argument.
the date argument is a string in the iso way, as the string value of a datetime object, then a plus or a minus, two digits of hours, a colon, and two digits of minutes.
the part after the plus or the minus is the offset from utc.

```
.DateTime~new
.DateTime~new(fulldate [,offset])
.DateTime~new(year, month, day [,offset])
.DateTime~new(year, month, day, hours, minutes, seconds [,microseconds] [,offset])
```
fulldate: a count of microseconds from the start of the first day of the first year
this method is a class method.
this method gives a new datetime object; the init method of this class sets its value.
with no arguments, the new object is the date and the time now.
with only the fulldate argument, the new object is the start of the first day of the year 1, plus that count of microseconds.
with the year, month, and day arguments only, the new object is the start of that day.
with the other arguments, the new object is the time that the year, month, day, hours, minutes, seconds, and microseconds arguments say.
each of these arguments must be a whole number in the range of its part of the time.
the year must be from 1 to 9999, and the minutes must be from 0 to 59.
the offset argument is optional; it is the offset from utc, in minutes.
the offset must be a whole number from -900 to 900, or a timespan object of the same value.
the default offset is the offset of the system now.
the code:
```rexx
today = .DateTime~new              -- current date and time
say .DateTime~new(date('F', "20170630", "S"))
say .DateTime~new(2017, 6, 30)
say .DateTime~new(2017, 6, 30, 11, 8, 50)
```
the result:
```
2017-06-30T00:00:00.000000
2017-06-30T00:00:00.000000
2017-06-30T11:08:50.000000
```
the reference says:
```
2017-06-30T00:00:00.000000
2017-06-30T00:00:00.000000
2017-06-30T11:08:50.000000
```

```
.DateTime~+(argument)
.DateTime~-(argument)
```
these methods do maths with the receiver datetime object and give a new object.
these methods do not change the receiver.
the first method adds a timespan object to the receiver, and gives a new datetime object.
the timespan in the argument can be positive or negative.
with the second method, if the argument is a datetime object, the result is a timespan object: the interval between the two times.
if the receiver is less than the argument, this interval is negative.
with the second method, if the argument is a timespan object, the method subtracts it from the receiver, and gives a new datetime object.
the timespan in the argument can be positive or negative.
a minus as a prefix operator on a datetime object raises a syntax error condition.
a plus as a prefix operator gives a new datetime object with the same time.
these methods do not know about a minute with one more second, as at the end of the year 2016 in utc.
the code:
```rexx
t = .dateTime~new~timeOfDay            -- returns TimeSpan for current time
say t                                  -- displays "17:30:41.482000", perhaps
d = .dateTime~new(2016, 12, 31)        -- creates new date
future = d + t                         -- adds timespan to d
say future                             -- displays "2016-12-31T17:30:41.482000"
-- does not take leap second into account
say d + .TimeSpan~new(24, 0, 1)   -- 2017-01-01T00:00:01.000000
                                  -- "real" start of next century
nextCentury = .dateTime~new(2101, 1, 1)
-- "The next century starts in 29547.07:15:42.721000 days", perhaps
say "The next century starts in" (nextCentury - .dateTime~new) "days"
```
the result:
```
88.907
```
the reference says:
```
17:30:41.482000
2016-12-31T17:30:41.482000
2017-01-01T00:00:01.000000
The next century starts in 29547.07:15:42.721000 days
```

```
.DateTime~compareTo(other)
```
this method gives -1 if the other argument is more than the receiver.
this method gives 0 if the two objects are equal.
this method gives 1 if the other argument is less than the receiver.

```
.DateTime~weekNumber
```
this method gives the number of the week of the receiver in the iso way.
each year has weeks with numbers from 1 to 52, or from 1 to 53.
the code:
```rexx
say weekNumber(2018, 12, 31)
say weekNumber(2019, 1, 1)
say weekNumber(2020, 12, 31)
say weekNumber(2021, 1, 1)
return

weekNumber: procedure
  date = .DateTime~new(arg(1), arg(2), arg(3))
  return date~weekNumber date~weekNumberDate
```
the result:
```
1 2019-W01-1
1 2019-W01-2
53 2020-W53-4
53 2020-W53-5
```
the reference says:
```
1 2019-W01-1
1 2019-W01-2
53 2020-W53-4
53 2020-W53-5
```

```
.DateTime~weekNumberDate
```
this method gives the receiver as a string in the iso way for a week: four digits of the year, a dash, the first letter of the word week in upper, two digits of the number of the week, a dash, and one digit of the day in the week.
the parts have zero digits at the left as they need.
a class method of this class makes a datetime object from a string in this way.
the code:
```rexx
say .DateTime~new(2018, 12, 31)~weekNumberDate
say .DateTime~new(2019, 1, 1)~weekNumberDate
say .DateTime~new(2020, 12, 31)~weekNumberDate
say .DateTime~new(2021, 1, 1)~weekNumberDate
```
the result:
```
2019-W01-1
2019-W01-2
2020-W53-4
2020-W53-5
```
the reference says:
```
2019-W01-1
2019-W01-2
2020-W53-4
2020-W53-5
```

```
.DateTime~weekNumberYear
```
this method gives the year of the number of the week of the receiver in the iso way.
for a day at the start or at the end of a year, this year can be the next year or the year before.
the code:
```rexx
say weekNumber(2018, 12, 31)
say weekNumber(2019, 1, 1)
say weekNumber(2020, 12, 31)
say weekNumber(2021, 1, 1)
return

weekNumber: procedure
  date = .DateTime~new(arg(1), arg(2), arg(3))
  return date~weekNumberYear date~weekNumberDate
```
the result:
```
2019 2019-W01-1
2019 2019-W01-2
2020 2020-W53-4
2020 2020-W53-5
```
the reference says:
```
2019 2019-W01-1
2019 2019-W01-2
2020 2020-W53-4
2020 2020-W53-5
```

```
.DateTime~weeksInYear
```
this method gives the count of weeks in the year of the receiver, by the rules of the iso way.
each year has 52 or 53 weeks in the iso way.
the code:
```rexx
do year = 2010 to 2030
  d = .DateTime~new(year, 6, 30)
  if d~weeksInYear \= 52 then
    say year":" d~weeksinYear
end
```
the result:
```
2015: 53
2020: 53
2026: 53
```
the reference says:
```
2015: 53
2020: 53
2026: 53
```

```
.DateTime~year
```
this method gives the year of the receiver.

```
.DateTime~month
```
this method gives the month of the receiver.

```
.DateTime~day
```
this method gives the day of the receiver.

```
.DateTime~hours
```
this method gives the count of whole hours in the receiver from midnight.

```
.DateTime~minutes
```
this method gives the minutes part of the time of day of the receiver.

```
.DateTime~ordinalDate
```
this method gives the receiver as a string of four digits of the year, a dash, and three digits of the number of the day in the year.
the parts have zero digits at the left as they need.
a class method of this class makes a datetime object from a string in this way.
the code:
```rexx
say .DateTime~new(2020, 2, 10)~ordinalDate
```
the result:
```
2020-041
```
the reference says:
```
2020-041
```

```
.DateTime~seconds
```
this method gives the seconds part of the time of day of the receiver.

```
.DateTime~makeString
```
this method gives the receiver as a string in the iso way, as the string method gives.
this method and the string method are the same.

```
.DateTime~microseconds
```
this method gives the microseconds part of the time of day of the receiver.

```
.DateTime~dayMinutes
```
this method gives the count of minutes from midnight to the time of day of the receiver.

```
.DateTime~daySeconds
```
this method gives the count of seconds from midnight to the time of day of the receiver.

```
.DateTime~dayMicroseconds
```
this method gives the count of microseconds from midnight to the time of day of the receiver.

```
.DateTime~hashCode
```
this method gives a string value that is the hash of the receiver.
a map collection uses this hash.

```
.DateTime~addYears(years)
```
this method gives a new datetime object: the receiver with the count of years in the argument added to it.
this method does not change the receiver.
the argument must be a whole number.
if the argument is negative, this method subtracts the years.
this method uses the rules of leap years.
if the result is the last day of the second month of a year that is not a leap year, the result is the day before it.
the code:
```rexx
date = .DateTime~new(2016, 6, 30)
say date
say date~addYears(1)
```
the result:
```
2016-06-30T00:00:00.000000
2017-06-30T00:00:00.000000
```
the reference says:
```
2016-06-30T00:00:00.000000
2017-06-30T00:00:00.000000
```

```
.DateTime~addWeeks(weeks)
```
this method gives a new datetime object: the receiver with the count of weeks in the argument added to it.
this method does not change the receiver.
the argument must be a number; it can have a fractional part.
if the argument is negative, this method subtracts the weeks.

```
.DateTime~addDays(days)
```
this method gives a new datetime object: the receiver with the count of days in the argument added to it.
this method does not change the receiver.
the argument must be a number; it can have a fractional part.
if the argument is negative, this method subtracts the days.
the code:
```rexx
date = .DateTime~new(2016, 6, 30)
say date
say date~addDays(1.5)
```
the result:
```
2016-06-30T00:00:00.000000
2016-07-01T12:00:00.000000
```
the reference says:
```
2016-06-30T00:00:00.000000
2016-07-01T12:00:00.000000
```

```
.DateTime~addHours(hours)
```
this method gives a new datetime object: the receiver with the count of hours in the argument added to it.
this method does not change the receiver.
the argument must be a number; it can have a fractional part.
if the argument is negative, this method subtracts the hours.

```
.DateTime~addMinutes(minutes)
```
this method gives a new datetime object: the receiver with the count of minutes in the argument added to it.
this method does not change the receiver.
the argument must be a number; it can have a fractional part.
if the argument is negative, this method subtracts the minutes.

```
.DateTime~addSeconds(seconds)
```
this method gives a new datetime object: the receiver with the count of seconds in the argument added to it.
this method does not change the receiver.
the argument must be a number; it can have a fractional part.
if the argument is negative, this method subtracts the seconds.

```
.DateTime~addMicroseconds(microseconds)
```
this method gives a new datetime object: the receiver with the count of microseconds in the argument added to it.
this method does not change the receiver.
the argument must be a whole number.
if the argument is negative, this method subtracts the microseconds.

```
.DateTime~isoDate
```
this method gives the receiver as a string in the iso way.
the string method gives the same value.

```
.DateTime~utcIsoDate
```
this method gives the receiver as a string in the iso way, with its offset from utc at the end.
if the offset is 0, the string ends with the last letter of the english letters, in upper.
if the offset is positive, the string ends with a plus, two digits of hours, a colon, and two digits of minutes.
if the offset is negative, the string ends with a minus, two digits of hours, a colon, and two digits of minutes.

```
.DateTime~baseDate
```
this method gives the count of whole days from the first day of the year 1 to the day of the receiver, with that first day but not with the day of the receiver.
the result has no zero digits and no blanks at the left.
this class uses the rules of years of now for each year from the year 1: 365 days in a year, and one more day in each year that you can divide by 4, but not in a year that you can divide by 100 and not by 400.
this method does not use any rules of years that are not these rules.

```
.DateTime~yearDay
```
this method gives the count of days in the year of the receiver to the day of the receiver, with the day of the receiver.
the result has no zero digits and no blanks at the left.
the code:
```rexx
say .DateTime~new(2020, 2, 10)~yearDay
```
the result:
```
41
```
the reference says:
```
41
```

```
.DateTime~weekDay
```
this method gives the day of the week of the receiver as a whole number.
the number is from 1 to 7, in the iso way: 1 is the first day of the week, and 7 is the last day.

```
.DateTime~europeanDate([separator])
```
this method gives the date of the receiver as a string of two digits of the day, two digits of the month, and the last two digits of the year, with a separator between them.
the separator argument is optional; it is the character between the parts of the result.
the separator must be one character or an empty string.
the default separator is a slash.

```
.DateTime~languageDate
```
this method gives the date of the receiver as a string: the day, the name of the month in the language of the system, and the four digits of the year.
if the system has no way for this, the result is in the default way.
a program must use this result as one thing, and must not use a rule about the way or the words of it.

```
.DateTime~monthName
```
this method gives the english name of the month of the receiver.

```
.DateTime~dayName
```
this method gives the english name of the day of the week of the receiver.

```
.DateTime~normalDate([separator])
```
this method gives the date of the receiver as a string of the day, the first three letters of the english name of the month, and the four digits of the year, with a separator between them.
the separator argument is optional; it is the character between the parts of the result.
the separator must be one character or an empty string.
the default separator is a blank.

```
.DateTime~orderedDate([separator])
```
this method gives the date of the receiver as a string of the last two digits of the year, two digits of the month, and two digits of the day, with a separator between them.
the separator argument is optional; it is the character between the parts of the result.
the separator must be one character or an empty string.
the default separator is a slash.

```
.DateTime~standardDate([separator])
```
this method gives the date of the receiver as a string of four digits of the year, two digits of the month, and two digits of the day, with a separator between them.
the separator argument is optional; it is the character between the parts of the result.
the separator must be one character or an empty string.
the default separator is an empty string.

```
.DateTime~usaDate([separator])
```
this method gives the date of the receiver as a string of two digits of the month, two digits of the day, and the last two digits of the year, with a separator between them.
the separator argument is optional; it is the character between the parts of the result.
the separator must be one character or an empty string.
the default separator is a slash.

```
.DateTime~civilTime
```
this method gives the time of the receiver as a string of the hours, a colon, two digits of the minutes, and then two letters.
the hours go from 1 to 12, with no zero at the left.
the minutes go from 00 to 59.
the two letters say if the time is in the first part of the day or in the rest of the day, as the time builtin function gives with its option for this way.
the minutes are the minutes of the time, and this method does not round them.

```
.DateTime~normalTime
```
this method gives the time of the receiver as a string of two digits each of the hours, the minutes, and the seconds, with a colon between them.
the hours go from 00 to 23, and the minutes and the seconds go from 00 to 59.
this method takes away the fractional part of the seconds, and does not round it.

```
.DateTime~longTime
```
this method gives the time of the receiver as a string of two digits each of the hours, the minutes, and the seconds with a colon between them, a period, and six digits of microseconds.

```
.DateTime~fullDate
```
this method gives the count of microseconds from the start of the first day of the year 1 to the receiver.
the result has no zero digits and no blanks at the left.

```
.DateTime~utcDate
```
this method gives the receiver as a utc time: the count of microseconds from the start of the first day of the year 1.
the result has no zero digits and no blanks at the left.

```
.DateTime~toLocalTime
```
this method gives a new datetime object for the same time in the local time of the system.

```
.DateTime~toUtcTime
```
this method gives a new datetime object for the same time in utc, with the offset 0.

```
.DateTime~toTimezone([offset])
```
this method gives a new datetime object for the same time with the offset in the argument.
the offset argument is optional; it is the offset from utc, in minutes.
the offset must be a whole number from -900 to 900, or a timespan object of the same value.
the default offset is 0, so the default result is a datetime object in utc.

```
.DateTime~ticks
```
this method gives the count of seconds from the start of the first day of the year 1970 to the receiver.
the result has no zero digits and no blanks at the left.
for a time before the year 1970, the result is negative.

```
.DateTime~offset
```
this method gives the offset of the receiver from utc, in minutes.
for a place east of utc, the offset is positive.
for a place west of utc, the offset is negative.

```
.DateTime~date
```
this method gives a new datetime object for the day of the receiver, with the time 00:00:00.000000.

```
.DateTime~timeOfDay
```
this method gives a timespan object: the interval from the start of the day of the receiver to the time of the receiver.

```
.DateTime~elapsed
```
elapsed: the time from a time before now to now is elapsed
this method gives a timespan object: the interval from the receiver to the date and time now.
if the receiver is in the future, this timespan is negative.

```
.DateTime~isLeapYear
```
this method gives true if the year of the receiver is a leap year, else false.

```
.DateTime~daysInMonth
```
this method gives the count of days in the month of the receiver.
for a day in the first month, the result is 31.
this method uses the rules of leap years: for the second month, the result is 28 in a year that is not a leap year, and 29 in a leap year.

```
.DateTime~daysInYear
```
this method gives the count of days in the year of the receiver.
the result is 366 for a leap year, and 365 for other years.

```
.DateTime~string
```
this method gives the receiver as a string in the iso way.
the method of this class for the iso date gives the same value.

## the timespan class

```
.TimeSpan
```
an object of this class is an interval of time, with microseconds as its least part.
the interval can be positive or negative.
the most an interval can be is 3652059 days less one of the microseconds, about 9999 years.
this class has methods to give the parts of the interval, as days or seconds, to add to the parts, and to do maths with two timespan objects.
this class inherits the mixin classes orderable and comparable.
so you can compare two timespan objects with each compare operator.

```
.TimeSpan~fromDays(days)
```
this method is a class method.
this method makes a timespan object from the count of days in the argument.
the argument must be a number.

```
.TimeSpan~fromHours(hours)
```
this method is a class method.
this method makes a timespan object from the count of hours in the argument.
the argument must be a number.

```
.TimeSpan~fromMinutes(minutes)
```
this method is a class method.
this method makes a timespan object from the count of minutes in the argument.
the argument must be a number.

```
.TimeSpan~fromSeconds(seconds)
```
this method is a class method.
this method makes a timespan object from the count of seconds in the argument.
the argument must be a number.

```
.TimeSpan~fromMicroseconds(microseconds)
```
this method is a class method.
this method makes a timespan object from the count of microseconds in the argument.
the argument must be a number.

```
.TimeSpan~fromNormalTime(time)
```
this method is a class method.
this method makes a timespan object from a string in the way that the time builtin function gives with the normal option: two digits each of the hours, the minutes, and the seconds, with a colon between them.
the interval of the timespan object is the time of day in the string.

```
.TimeSpan~fromCivilTime(time)
```
this method is a class method.
this method makes a timespan object from a string of the hours from 1 to 12, a colon, two digits of the minutes, and then two letters that say if the time is in the first part of the day or in the rest of the day.
the interval of the timespan object is the time of day in the string.

```
.TimeSpan~fromLongTime(time)
```
this method is a class method.
this method makes a timespan object from a string in the way that the time builtin function gives with the long option: two digits each of the hours, the minutes, and the seconds with a colon between them, a period, and six digits of microseconds.
the interval of the timespan object is the time of day in the string.

```
.TimeSpan~fromStringFormat(time)
```
this method is a class method.
this method makes a timespan object from a string in the way that the string method of this class gives.

```
.TimeSpan~new(fulldate)
.TimeSpan~new(hours, minutes [,seconds])
.TimeSpan~new(days, hours, minutes, seconds [,microseconds])
```
this method is a class method.
this method gives a new timespan object; the init method of this class sets its value.
with only the first argument, the interval is that count of microseconds.
else the interval is the hours, minutes, and seconds, or the days, hours, minutes, seconds, and microseconds in the arguments.
each of these arguments must be a whole number in the range of its part of the time.
the hours must be from 0 to 23, and the minutes must be from 0 to 59.
the code:
```rexx
say .TimeSpan~new(time('F', "15:37:30", "N"))
say .TimeSpan~new(15, 37, 30)
say .TimeSpan~new(6, 4, 33, 15, 100)
```
the result:
```
15:37:30.000000
15:37:30.000000
6.04:33:15.000100
```
the reference says:
```
15:37:30.000000
15:37:30.000000
6.04:33:15.000100
```

```
.TimeSpan~+(argument)
.TimeSpan~-(argument)
.TimeSpan~*(argument)
.TimeSpan~/(argument)
.TimeSpan~%(argument)
.TimeSpan~//(argument)
```
these methods do maths with the receiver timespan object and give a new object.
these methods do not change the receiver or the argument.
with the first method, if the argument is a datetime object, the result is a new datetime object: the argument with the receiver added to it.
the timespan can be positive or negative.
with the first method, if the argument is a timespan object, the result is a new timespan object: the sum of the two.
with the second method, the argument must be a timespan object; the result is a new timespan object: the receiver less the argument.
with the third method, the argument must be a number; the result is a new timespan object: the receiver times the argument.
with the fourth method, the argument must be a number; the result is a new timespan object: the receiver divide by the argument.
the fifth method is an integer divide; the argument must be a number, and the result is a new timespan object.
the fourth method and the fifth method give the same result.
with the last method, the argument must be a number; the result is a new timespan object: the remainder when you divide the receiver by the argument.
a minus as a prefix operator gives a new timespan object with the sign of the receiver changed.
a plus as a prefix operator gives a new timespan object with the same value.
the code:
```rexx
t1 = .timespan~fromHours(1)
t2 = t1 * 2
say t1 t2 (t1 + t2)
```
the result:
```
01:00:00.000000 02:00:00.000000 03:00:00.000000
```
the reference says:
```
01:00:00.000000 02:00:00.000000 03:00:00.000000
```

```
.TimeSpan~compareTo(other)
```
this method gives -1 if the other argument is more than the receiver.
this method gives 0 if the two objects are equal.
this method gives 1 if the other argument is less than the receiver.

```
.TimeSpan~duration
```
duration: a length of time that is not negative
this method gives a new timespan object with the absolute value of the receiver.

```
.TimeSpan~days
```
this method gives the count of whole days in the receiver, as a positive number.

```
.TimeSpan~hours
```
this method gives the hours part of the receiver, as a positive number.

```
.TimeSpan~minutes
```
this method gives the minutes part of the receiver, as a positive number.

```
.TimeSpan~seconds
```
this method gives the seconds part of the receiver, as a positive number.

```
.TimeSpan~makeString
```
this method gives the receiver as a string, in the way that the string method gives.
this method and the string method are the same.

```
.TimeSpan~microseconds
```
this method gives the microseconds part of the receiver, as a positive number.

```
.TimeSpan~totalDays
```
this method gives the receiver as a count of days.
the result has the fractional part, and the sign of the receiver.

```
.TimeSpan~totalHours
```
this method gives the receiver as a count of hours.
the result has the fractional part, and the sign of the receiver.

```
.TimeSpan~totalMinutes
```
this method gives the receiver as a count of minutes.
the result has the fractional part, and the sign of the receiver.

```
.TimeSpan~totalSeconds
```
this method gives the receiver as a count of seconds.
the result has the fractional part, and the sign of the receiver.

```
.TimeSpan~totalMicroseconds
```
this method gives the receiver as a count of microseconds.
the result has the sign of the receiver.

```
.TimeSpan~hashCode
```
this method gives a string value that is the hash of the receiver.
a map collection, as a table, a relation, a set, a bag, or a directory, uses this hash.

```
.TimeSpan~addWeeks(weeks)
```
this method gives a new timespan object: the receiver with the count of weeks in the argument added to it.
this method does not change the receiver.
the argument must be a number; it can have a fractional part.
if the argument is negative, this method subtracts the weeks.

```
.TimeSpan~addDays(days)
```
this method gives a new timespan object: the receiver with the count of days in the argument added to it.
this method does not change the receiver.
the argument must be a number; it can have a fractional part.
if the argument is negative, this method subtracts the days.

```
.TimeSpan~addHours(hours)
```
this method gives a new timespan object: the receiver with the count of hours in the argument added to it.
this method does not change the receiver.
the argument must be a number; it can have a fractional part.
if the argument is negative, this method subtracts the hours.

```
.TimeSpan~addMinutes(minutes)
```
this method gives a new timespan object: the receiver with the count of minutes in the argument added to it.
this method does not change the receiver.
the argument must be a number; it can have a fractional part.
if the argument is negative, this method subtracts the minutes.

```
.TimeSpan~addSeconds(seconds)
```
this method gives a new timespan object: the receiver with the count of seconds in the argument added to it.
this method does not change the receiver.
the argument must be a number; it can have a fractional part.
if the argument is negative, this method subtracts the seconds.

```
.TimeSpan~addMicroseconds(microseconds)
```
this method gives a new timespan object: the receiver with the count of microseconds in the argument added to it.
this method does not change the receiver.
the argument must be a whole number.
if the argument is negative, this method subtracts the microseconds.

```
.TimeSpan~sign
```
this method gives -1 if the receiver is negative, 1 if it is positive, and 0 if it is zero.

```
.TimeSpan~string
```
this method gives the receiver as a string: a minus sign if it is negative, the days, a period, two digits each of the hours, the minutes, and the seconds with a colon between them, a period, and six digits of microseconds.
if the receiver is positive or zero, the string has no sign.
the days have no zero digits and no blanks at the left.
if the receiver is less than a day, the string has no days and no period before the hours.

## the alarm class

```
.Alarm
```
an alarm object sends a message to a target object at the time you set: then the alarm is triggered.
you can cancel an alarm before it is triggered.
if you cancel it, the alarm also sends a message to the target.

```
.Alarm~attachment
```
attachment: an object that you give to an alarm or a ticker when you make it, so that you can get it back after that
this method gives the attachment of the receiver.
if the receiver has no attachment, this method gives nil.
the new method of this class says more.
the code:
```rexx
oneSecond = .Alarm~new(1, .Target~new, "a second has passed")
call SysSleep 1.5                      -- give Alarm time to trigger
oneSecond~cancel

::class Target inherit AlarmNotification
::method triggered                     -- called when Alarm triggers
  use arg alarm
  say alarm~attachment                 -- displays "a second has passed"
```
the result:
```
a second has passed
```
the reference says:
```
a second has passed
```

```
.Alarm~cancel
```
this method makes a cancel of the alarm of the receiver, if it is not triggered yet.
if the time of the alarm is now or before now, this method does nothing.

```
.Alarm~canceled
.Alarm~cancelled
```
canceled: an alarm is canceled when you cancel it
cancelled: canceled
these two methods are the same.
they give true if the alarm got a cancel before it was triggered, else false.
the code:
```rexx
alarm = .Alarm~new(1 ,.message~new(.stdout, "SAY", "I", "Alarm went off"))
call SysSleep 0.5
alarm~cancel
say "Alarm" alarm~cancelled~?("cancelled", "not cancelled")
```
the result:
```
Alarm cancelled
```
the reference says:
```
Alarm cancelled
```

```
.Alarm~new(atime, target [,attachment])
```
this method is a class method.
this method gives a new alarm object; the init method of this class sets it.
the first argument is the time in the future when the alarm sends the triggered message to the target in the second argument.
the target must have the methods of the alarmnotification mixin: it must inherit that class, or be a subclass of it.
the target can also be a message object, as the message class inherits the alarmnotification class.
if the target is a message object, its triggered method sends its message.
the first argument can be a datetime object, a timespan object, or a string.
if it is a datetime object, it is the time when the alarm is triggered, and it must be in the future.
if it is a timespan object, the alarm is triggered at the time now plus that interval, and the interval must not be negative.
if it is a string, it is a time, as two digits each of the hours, the minutes, and the seconds with a colon between them, or a number of seconds from now.
with a time in the string, you can put a date after the time, with one blank between them.
the date must be in the default way of the date builtin function: the day, the first three letters of the english name of the month, and the four digits of the year.
the string must have no blank or tab characters at the start or at the end.
if the string has no date, the alarm uses the first time after now that has the time in the string.
the attachment argument is optional; it can be any object.
the alarm keeps the attachment, and the method that gets the triggered message can get it with the attachment method.
you can use the cancel method to cancel an alarm that is not triggered yet.
if you cancel it, the alarm sends the cancel message to the target.
the next code sets an alarm for 17:10 on the 15 day of the last month of the year 2017.
the code:
```rexx
/* Alarm Examples */
PersonalMessage = .MyMessageClass~new("Call the Bank")
msg = .Message~new(PersonalMessage, "RemindMe")
time = .DateTime~fromIsoDate("2017-12-15T17:10:00.000000")
a = .Alarm~new(time, msg)
exit

::class MyMessageClass public
::method init
  expose inmsg
  use arg inmsg
::method RemindMe
  expose inmsg
  say "It is now" time("C")". Please" inmsg
  /* On the specified data and time, displays the following message: */
  /* "It is now 5:10pm. Please Call the Bank" */
```
the result:
```
93.951
```
the next code uses the same message object, and sets an alarm to send it 30 seconds from now.
the code:
```rexx
PersonalMessage = .MyMessageClass~new("Call the Bank")
msg = .Message~new(PersonalMessage, "RemindMe")
a = .Alarm~new(30, msg)
exit

::class MyMessageClass public
::method init
  expose inmsg
  use arg inmsg
::method RemindMe
  expose inmsg
  say "It is now" time("C")". Please" inmsg
```
the result:
```
not run: it did not end in ten seconds
```

```
.Alarm~scheduledTime
```
this method gives a datetime object for the time that the alarm was set for when it was made.

```
.Alarm~triggered
```
this method gives true if the alarm is triggered.
this method gives false if the alarm got a cancel, or if it is not triggered yet.

## the alarmnotification class

```
.AlarmNotification
```
this class has the methods that an alarm or a ticker sends to its target.
an alarm or a ticker sends these messages to the target that you give when you make it.
the target must have the methods of this class.
when the alarm or ticker is triggered, it sends the triggered message to the target.
when the alarm or ticker gets a cancel, it sends the cancel message to the target.
this class is a mixin.

```
.AlarmNotification~cancel(source)
```
an alarm or a ticker sends this message to its target when it gets a cancel.
the argument is the alarm or ticker that got the cancel.
in this class, this method does nothing, so a class that inherits this class does not have to have this method.

```
.AlarmNotification~triggered(source)
```
an alarm or a ticker sends this message to its target when it is triggered.
the argument is the alarm or ticker that is triggered.
this method is abstract: a class that inherits this class must have this method.
the example of the attachment method of the alarm class uses this method.

## the ticker class

```
.Ticker
```
a ticker object sends a message to a target object again and again: each time an interval ends, the ticker is triggered.
you can cancel a ticker at any time.
if you cancel it, the ticker sends the cancel message to the target.

```
.Ticker~attachment
```
this method gives the attachment of the receiver.
if the receiver has no attachment, this method gives nil.
the new method of this class says more.
the code:
```rexx
eachSecond = .Ticker~new(1, .Target~new, "once each second")
call SysSleep 1.5                      -- will trigger once
eachSecond~cancel

::class Target inherit AlarmNotification
::method triggered                     -- called each interval
  use arg ticker
  say ticker~attachment                -- displays "once each second"
```
the result:
```
once each second
```
the reference says:
```
once each second
```

```
.Ticker~cancel
```
this method makes a cancel of the ticker of the receiver.
the code:
```rexx
twiceASecond = .Ticker~new(0.5, .Target~new)
call SysSleep 0.25                     -- too short for Ticker
twiceASecond~cancel                    -- "ticker cancelled"

::class Target inherit AlarmNotification
::method triggered                     -- called each interval
  say "ticker triggered"
::method cancel                        -- called when cancelled
  say "ticker cancelled"
```
the result:
```
ticker cancelled
```
the reference says:
```
ticker cancelled
```

```
.Ticker~canceled
.Ticker~cancelled
```
these two methods are the same.
they give true if the ticker got a cancel, else false.
the code:
```rexx
tick = .Ticker~new(0.5 ,.message~new(.stdout, "SAY", "I", "knock, knock"))
call SysSleep 0.75
say "Ticker" tick~cancelled~?("cancelled", "not cancelled")
call SysSleep 0.5
tick~cancel
say "Ticker" tick~cancelled~?("cancelled", "not cancelled")
```
the result:
```
knock, knock
Ticker not cancelled
knock, knock
Ticker cancelled
```
the reference says:
```
knock, knock
Ticker not cancelled
knock, knock
Ticker cancelled
```

```
.Ticker~new(interval, target [,attachment])
```
this method is a class method.
this method gives a new ticker object; the init method of this class sets it.
after each interval, the ticker sends the triggered message to the target in the second argument.
the target must have the methods of the alarmnotification mixin: it must inherit that class, or be a subclass of it.
the target can also be a message object, as the message class inherits the alarmnotification class.
if the target is a message object, its triggered method sends its message.
the first argument can be a timespan object or a string.
if it is a timespan object, it must not be negative; it is the length of the interval.
if it is a string, it must be a number that is not negative; it is the length of the interval in seconds.
the attachment argument is optional; it can be any object.
the ticker keeps the attachment, and the method that gets the triggered message can get it with the attachment method.
you can use the cancel method at any time to cancel a ticker.
if you cancel it, the ticker sends the cancel message to the target.
the next code uses a ticker to show what part of a long task is done, while the task runs.
the code:
```rexx
.Progress~new(0.5)~monitor(.Task~new, "tenSeconds")

-- defines tasks together with their "progress" methods
::class Task
-- long-running task
::method tenSeconds unguarded
  expose m n
  n = 1000
  do m = 1 to n                             -- long-running task
    call SysSleep 0.01
  end
  return

-- returns running value to be displayed as progress
::method "tenSeconds-progress" unguarded
  expose m n
  return m"/"n "steps done"

-- runs task while displaying progress text at each interval
::class Progress inherit AlarmNotification
-- set progress interval
::method init unguarded
  expose interval
  use strict arg interval = 1

-- starts ticker, runs task, and returns task result
-- (requires names of task and progress methods)
::method monitor
  expose interval object progress
  use strict arg object, task, progress = (task"-progress")
  tick = .Ticker~new(interval, self)
  object~send(task)
  tick~cancel

-- displays progress text at each ticker interval
::method triggered unguarded
  expose object progress
  .stdout~charOut(object~send(progress) '0d'x)
```
the result:
```
not run: it did not end in ten seconds
```

```
.Ticker~interval
```
this method gives a timespan object for the interval of the ticker.
the code:
```rexx
say .Ticker~new(.TimeSpan~fromSeconds(60), -
 .Message~new(.stdout, "say", "i", -
 "another minute has passed"))~interval
```
the result:
```
not run: it did not end in ten seconds
```
the reference says:
```
00:01:00.000000
```

## the eventsemaphore class

```
.EventSemaphore
```
post: set an event semaphore, so that the activities that wait for it go on to run
posted: an event semaphore is posted after you post it
reset: set an event semaphore so that it is not posted
an event semaphore is a way to say to activities when a condition, the event, is true.
you set the event when you post the semaphore, and you take it away when you reset the semaphore.
an activity is a part of a program that runs at the same time as other parts.
an activity can wait for the event; when the event is true, the activity goes on to run.

```
.EventSemaphore~new
```
this method is a class method.
this method gives a new event semaphore.
at the start, the semaphore is not posted.

```
.EventSemaphore~isPosted
```
this method gives true if the semaphore is posted, and false if it is not posted.
the code:
```rexx
sem = .EventSemaphore~new
say sem~isPosted
sem~post
say sem~isPosted
```
the result:
```
0
1
```
the reference says:
```
0
1
```

```
.EventSemaphore~post
```
this method makes the semaphore posted.
each activity that waits for this semaphore goes on to run.
when the semaphore is posted, an activity that calls the wait method goes on to run and does not wait.

```
.EventSemaphore~reset
```
this method makes the semaphore not posted.
while the semaphore is not posted, each activity that calls the wait method waits.

```
.EventSemaphore~uninit
```
this method does the last work for the semaphore when the computer takes it away from memory as garbage.
do not call this method; only the uninit method of a subclass of this class may call it.
if a subclass of this class has an uninit method, that method must call the uninit method of the superclass.

```
.EventSemaphore~wait([timeout])
```
this method gives true if the semaphore got posted while the activity was in a wait, or if it is posted now.
this method gives false if the time in the argument got to its end before the semaphore got posted.
the argument is optional; it must be a timespan object or a number.
if the argument is negative, or if you omit it, this method waits until the semaphore is posted.
if the argument is zero, this method does not wait; it gives true if the semaphore is posted now, else false.
if the argument is positive, this method waits for that count of seconds, or until the semaphore is posted, which is first.
any number of activities can wait for one event semaphore.
when the semaphore is posted, each activity that waits goes on to run.
the order in which these activities go on to run is not known, and a program must not use a rule about it.
the code:
```rexx
event = .EventSemaphore~new
say "main starts tasks"
do nr = 1 to 5
  .task~new~waitFor(event, "task" nr)
end
call SysSleep 0.1
say "main posts"
event~post
say "main ends"

::class Task
::method waitFor
  reply
  use strict arg event, name
  say name "waits"
  event~wait
  say name "runs"
```
the result:
```
main starts tasks
task 2 waits
task 1 waits
task 4 waits
task 3 waits
task 5 waits
main posts
main ends
task 1 runs
task 2 runs
task 4 runs
task 3 runs
task 5 runs
```
the reference says:
```
main starts tasks
task 2 waits
task 5 waits
task 1 waits
task 3 waits
task 4 waits
main posts
main ends
task 4 runs
task 3 runs
task 1 runs
task 2 runs
task 5 runs
```

## the mutexsemaphore class

```
.MutexSemaphore
```
mutex: a semaphore that only one activity can have at a time
acquire: get a mutex semaphore, so that no other activity can get it
release: give back a mutex semaphore, so that an other activity can get it
a mutex semaphore is a way for activities that run at the same time to use a resource one at a time.
with it, only one activity at a time runs the part of its code that uses that resource.
an activity must acquire the mutex semaphore before it runs that part, and release it after that part.
the guard instruction with on and with off says more.

```
.MutexSemaphore~new
```
this method is a class method.
this method gives a new mutex semaphore.
at the start, no activity has the semaphore.

```
.MutexSemaphore~acquire([timeout])
```
this method gives true if the activity of the caller had the semaphore before, or got it now.
this method gives false if an other activity has the semaphore, or if the time in the argument got to its end first.
an activity that has the semaphore can acquire it again; each time, the level of the semaphore is one more.
to let an other activity have the semaphore, the activity must release it the same number of times.
the argument is optional; it must be a timespan object or a number.
if the argument is negative, or if you omit it, this method waits until the activity can have the semaphore.
if the argument is zero, this method does not wait; it gives true if it got the semaphore, else false.
if the argument is positive, this method waits for that count of seconds, or until the activity can have the semaphore, which is first.
if an activity has a mutex semaphore when it ends, the language makes a release of it; this is so for each mutex semaphore that the activity has.
the code:
```rexx
mutex = .MutexSemaphore~new
.Task~new~startWork(mutex, "work 1")
.Task~new~startWork(mutex, "work 2")
say "work tasks started"

::class Task
::method startWork unguarded
  expose mutex name
  use strict arg mutex, name
  reply
  self~doWork(1)

::method doWork unguarded
  expose mutex name
  use strict arg level
  -- five levels of nested acquires
  if level > 5 then
    return
  mutex~acquire
  say name level
  self~doWork(level + 1)
```
the result:
```
work 2 1
work tasks started
work 2 2
work 2 3
work 2 4
work 2 5
work 1 1
work 1 2
work 1 3
work 1 4
work 1 5
```
the reference says:
```
work tasks started
work 2 1
work 2 2
work 2 3
work 2 4
work 2 5
work 1 1
work 1 2
work 1 3
work 1 4
work 1 5
```

```
.MutexSemaphore~release
```
this method gives true if the activity of the caller had the semaphore, else false.
a release that works makes the level of the semaphore one less.
when the level is zero, one of the activities that wait to acquire the semaphore, if there is one, gets it.

```
.MutexSemaphore~uninit
```
this method does the last work for the semaphore when the computer takes it away from memory as garbage.
do not call this method; only the uninit method of a subclass of this class may call it.
if a subclass of this class has an uninit method, that method must call the uninit method of the superclass.

## the monitor class

```
.Monitor
```
destination: the object that gets the messages that a monitor sends on
a monitor object is in the place of an other object: it sends the messages it gets on to its destination.
you can change the destination while the program runs.

```
.Monitor~current
```
this method gives the destination object of the monitor now.

```
.Monitor~destination([destination])
```
if you give the argument, it is the new destination for the messages that the monitor sends on.
if you omit the argument, the destination before the one now is the new destination.

```
.Monitor~new([destination])
```
this method is a class method.
this method gives a new monitor object; the init method of this class sets it.
the destination argument is optional.

```
.Monitor~unknown(messagename, messageargs)
```
the monitor sends each message that it has no method for on to its destination now.
the part of the reference about how to make an unknown method says more.
the code:
```rexx
.local~setentry("output",.monitor~new(.stream~new("my.new")~~command("open nobuffer")))
/* The following sets the destination */
previous_destination=.output~destination(.stream~new("my.out")~~command("open write"))
/* The following resets the destination */
.output~destination
.output~destination(.Stdout)
current_output_destination_stream_object=.output~current
```
the result:
```
```

## the messagenotification class

```
.MessageNotification
```
this class has the method that a message object sends when its message is completed.
you ask for this with the notify method of the message class.
the argument of the notify method is the target that gets the message; it must have the method of this class.
this class is a mixin.

```
.MessageNotification~messageComplete(source)
```
a message object sends this message to the target when its message is completed, if the notify method was used to ask for it.
the argument is the message object that is completed.
this method is abstract: a subclass must have this method.

