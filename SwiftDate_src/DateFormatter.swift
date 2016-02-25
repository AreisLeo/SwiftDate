//
//	SwiftDate, an handy tool to manage date and timezones in swift
//	Created by:				Daniele Margutti
//	Main contributors:		Jeroen Houtzager
//
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights
//	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the Software is
//	furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in
//	all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//	THE SOFTWARE.

import Foundation

//MARK: - DateFormatter Supporting Data -

/**
Constants for specifying how to spell out unit names.

- Positional 	A style that uses the position of a unit to identify its value and commonly used for time values where components are separated by colons (“1:10:00”)
- Abbreviated 	The abbreviated style represents the shortest spelling for unit values (ie. “1h 10m”)
- Short			A style that uses the short spelling for units (ie. “1hr 10min”)
- Full 			A style that spells out the units fully (ie. “1 hour, 10 minutes”)
- Colloquial	For some relevant intervals this style print out a more colloquial string representation (ie last moth
*/
public enum DateFormatterComponentsStyle {
	case Positional
	case Abbreviated
	case Short
	case Full
	case Colloquial
	
	public var localizedCode: String {
		switch self {
		case .Positional: 	return "positional";
		case .Abbreviated:	return "abbreviated";
		case .Short: 		return "short";
		case .Full: 		return "full";
		case .Colloquial: 	return "colloquial";
		}
	}
}

/**
*  Define how the formatter must work when values contain zeroes.
*/
public struct DateZeroBehavior: OptionSetType {
	public let rawValue: Int
	public init(rawValue: Int) { self.rawValue = rawValue }
	
		/// None, it does not remove components with zero values
	static let None			= DateZeroBehavior(rawValue:1)
		/// Units whose values are 0 are dropped starting at the beginning of the sequence until the first non-zero component
	static var DropLeading	= DateZeroBehavior(rawValue:3)
		/// Units whose values are 0 are dropped from anywhere in the middle of a sequence.
	static var DropMiddle	= DateZeroBehavior(rawValue:4)
		/// Units whose value is 0 are dropped starting at the end of the sequence back to the first non-zero component
	static var DropTrailing	= DateZeroBehavior(rawValue:5)
		/// This behavior drops all units whose values are 0. For example, when days, hours, minutes, and seconds are allowed, the abbreviated version of one hour is displayed as “1h”.
	static var DropAll		: DateZeroBehavior = [DropLeading,DropMiddle,DropTrailing]
}

//MARK: - DateFormatter Class -

/// The DateFormatter class is used to get a string representation of a time interval between two dates or a relative representation of a date
public class DateFormatter {
	/// Described the style in which each unit will be printed out
	public 			var unitsStyle: 			DateFormatterComponentsStyle = .Full
	/// Tell what kind of time units should be part of the output. Allowed values are a subset of the NSCalendarUnit mask
	/// .Year,.Month,.Day,.Hour,.Minute,.Second are supported (default values enable all of them)
	public			var allowedUnits:			NSCalendarUnit = [.Year,.Month,.Day,.Hour,.Minute,.Second]
	/// Number of units to print from the higher to the lower. Default is unlimited, all values could be part of the output
	public			var maxUnitCount:			Int?
	/// How the formatter threat zero components. Default implementation drop all zero values from the output string
	public			var zeroBehavior:			DateZeroBehavior = .DropAll
	/// If .unitStyle is .Colloquial you can include relevant date/time formatting to append after the colloquial representation
	/// For years it may print the month, for weeks or days it may print the hour:minute of the date. Default is false.
	public			var includeRelevantTime:	Bool = false
	/// For interval less than 5 minutes if this value is true the equivalent of 'just now' is printed in the output string
	public 			var allowsNowOnColloquial:	Bool = false
	
	/// This is the bundle where the localized data is placed
	private lazy var bundle: NSBundle? = {
		guard let frameworkBundle = NSBundle(identifier: "com.danielemagutti.SwiftDate") else { return nil }
		let path = NSURL(fileURLWithPath: frameworkBundle.resourcePath!).URLByAppendingPathComponent("SwiftDate.bundle")
		let bundle = NSBundle(URL: path)
		return bundle
	}()
	
	public init() {
		
	}
	
	/**
	Print the string representation of the interval amount (in seconds) since/to now. It supports both negative and positive values.
	
	- parameter interval interval of time in seconds
	
	- returns: output string representation of the interval
	*/
	public func toString(interval: NSTimeInterval) -> String? {
		let region_utc = Region(timeZoneName: TimeZoneName.Gmt)
		let fromDate = DateInRegion(absoluteTime: NSDate(timeIntervalSinceNow: -interval), region: region_utc)
		let toDate = DateInRegion(absoluteTime: NSDate(), region: region_utc)
		return self.toString(fromDate: fromDate, toDate: toDate)
	}
	
	/**
	Print the representation of the interval between two dates.
	
	- parameter f source date
	- parameter t end date
	
	- returns: output string representation of the interval
	*/
	public func toString(fromDate f: DateInRegion, toDate t: DateInRegion) -> String? {
		guard f.calendar.calendarIdentifier == t.calendar.calendarIdentifier else {
			return nil
		}
		if unitsStyle == .Colloquial {
			return toColloquialString(fromDate: f, toDate: t)
		} else {
			return toComponentsString(fromDate: f, toDate: t)
		}
	}
	
//MARK: Private Methods
	
	/**
	This method output the colloquial representation of the interval between two dates. You will not call it from the extern.
	
	- parameter f source date
	- parameter t end date
	
	- returns: output string representation of the interval
	*/
	private func toColloquialString(fromDate f: DateInRegion, toDate t: DateInRegion) -> String? {
		// Get the components of the date. Date must have the same parent calendar type in order to be compared
		let cal = f.calendar
		let opt = NSCalendarOptions(rawValue: 0)
		let components = cal.components(allowedUnits, fromDate: f.absoluteTime, toDate: t.absoluteTime, options: opt)
		let isFuture = (f.absoluteTime.timeIntervalSince1970 > t.absoluteTime.timeIntervalSince1970)
		
		
		if components.year != 0 { // Years difference
			let value = abs(components.year)
			let relevant_str = relevantTimeForUnit(.Year, date: f, value: value)
			return colloquialString(.Year, futureDate: isFuture, value: value, relevantStr: relevant_str, args: f.year!)
		}
		
		if components.month != 0 { // Months difference
			let value = abs(components.month)
			let relevant_str = relevantTimeForUnit(.Month, date: f, value: value)
			return colloquialString(.Month, futureDate: isFuture, value: value, relevantStr: relevant_str, args: value)
		}
		
		// Weeks difference
		let daysInWeek = f.calendar.rangeOfUnit(.Day, inUnit: .WeekOfMonth, forDate: f.absoluteTime).length
		if components.day >= daysInWeek {
			let weeksNumber = abs(components.day / daysInWeek)
			let relevant_str = relevantTimeForUnit(.WeekOfYear, date: f, value: weeksNumber)
			return colloquialString(.WeekOfYear, futureDate: isFuture, value: weeksNumber, relevantStr: relevant_str, args: weeksNumber)
		}
		
		if components.day != 0 { // Days difference
			let value = abs(components.day)
			let relevant_str = relevantTimeForUnit(.Day, date: f, value: value)
			return colloquialString(.Day, futureDate: isFuture, value: value, relevantStr: relevant_str, args: value)
		}

		if components.hour != 0 { // Hours difference
			let value = abs(components.hour)
			let relevant_str = relevantTimeForUnit(.Hour, date: f, value: value)
			return colloquialString(.Hour, futureDate: isFuture, value: value, relevantStr: relevant_str, args: value)
		}
		
		if components.minute != 0 { // Minutes difference
			let value = abs(components.minute)
			let relevant_str = relevantTimeForUnit(.Minute, date: f, value: value)
			if self.allowsNowOnColloquial == true && components.minute < 5 { // Less than 5 minutes ago is 'just now'
				return sd_localizedString("colloquial_now", arguments: [])
			}
			return colloquialString(.Minute, futureDate: isFuture, value: value, relevantStr: relevant_str, args: value)
		}
		
		if components.second != 0 { // Seconds difference
			let value = abs(components.second)
			let relevant_str = relevantTimeForUnit(.Second, date: f, value: value)
			if self.allowsNowOnColloquial == true { // It's 'now' if allowed
				return sd_localizedString("colloquial_now", arguments: [])
			}
			return colloquialString(.Second, futureDate: isFuture, value: value, relevantStr: relevant_str, args: value)
		}
		
		// Fallback to components output
		return self.toComponentsString(fromDate: f, toDate: t)
	}
	
	/**
	String representation between two dates by printing difference in term of each time unit component
	
	- parameter f from date
	- parameter t to date
	
	- returns: representation string
	*/
	private func toComponentsString(fromDate f: DateInRegion, toDate t: DateInRegion) -> String? {
		// Get the components of the date. Date must have the same parent calendar type in order to be compared
		let cal = f.calendar
		let opt = NSCalendarOptions(rawValue: 0)
		let components = cal.components(allowedUnits, fromDate: f.absoluteTime, toDate: t.absoluteTime, options: opt)
		let flags: [NSCalendarUnit] = [.Year,.Month,.Day,.Hour,.Minute,.Second]
		
		var output: [DateFormatterValue] = []
		var nonZeroUnitFound: Int = 0
		let value_separator = valueSeparator(forStyle: self.unitsStyle)
		for flag in flags {
			let unit_value = abs(components.valueForComponent(flag)) // get the value of the current unit
			let unit_name = unitNameWithValue(unit_value, unit: flag, style: self.unitsStyle)
			
			// Drop zero (all,leading,middle)
			let shouldDropZero = (unit_value == 0 && (zeroBehavior == .DropAll || zeroBehavior == .DropLeading && nonZeroUnitFound == 0 || zeroBehavior == .DropMiddle))
			if shouldDropZero == false {
				output.append( DateFormatterValue(name: unit_name, value: unit_value, separator: value_separator) )
			}
			
			nonZeroUnitFound += (unit_value != 0 ? 1 : 0)
			if maxUnitCount != nil && nonZeroUnitFound == maxUnitCount! { // limit the number of values to show
				break
			}
		}
		
		// Special routine to manage drop zero in traling
		if zeroBehavior == .DropTrailing {
			var endFromStart: Int?
			var endFromEnd: Int?
			for (var x = 0; x < output.count; x++) {
				let component = output[x]
				if component.value != 0 && endFromStart == nil {
					endFromStart = x
				} else if component.value == 0 && endFromStart != nil {
					endFromEnd = (output.count-x)
					break
				}
			}
			if endFromStart != nil { // remove from start
				output.removeRange(0..<endFromStart!)
			}
			if endFromEnd != nil { // remove at the end
				endFromEnd = (output.count-endFromEnd!)
				output.removeRange(endFromEnd!..<output.count)
			}
		}
		
		let unit_separator = unitSeparator(forStyle: self.unitsStyle) // separator between each unit of time (ie. ':')
		let str_components = output.map { (item) -> String in
			return item.description
			}.joinWithSeparator(unit_separator)
		return str_components
	}
	
	/**
	Get the readable name of a time unit
	
	- parameter value value of the time unit
	- parameter unit type of unit
	- parameter style style to use
	
	- returns: unit name
	*/
	private func unitNameWithValue(value: Int, unit: NSCalendarUnit, style: DateFormatterComponentsStyle) -> String {
		let localized_unit = unit.localizedCode(value)
		let localized_style = style.localizedCode
		let identifier = "unitname_\(localized_style)_\(localized_unit)"
		return sd_localizedString(identifier)
	}
	
	/**
	Get the value separator string (the string between the time unit value and the name)
	
	- parameter style style to use
	
	- returns: value separator
	*/
	private func valueSeparator(forStyle style: DateFormatterComponentsStyle) -> String {
		let identifier = "valuesep_\(style.localizedCode)"
		return sd_localizedString(identifier)
	}
	
	/**
	Get the unit separator string (the string between each time component unit, ie. ', ' in '2h, 4m')
	
	- parameter style style to use
	
	- returns: unit separator
	*/
	private func unitSeparator(forStyle style: DateFormatterComponentsStyle) -> String {
		let identifier = "unitsep_\(style.localizedCode)"
		return sd_localizedString(identifier)
	}
	
	/**
	Return the colloquial string representation of a time unit
	
	- parameter unit unit of time
	- parameter f target date to use
	- parameter value value of the unit
	- parameter relevantStr relevant time string to append at the end of the ouput
	- parameter args arguments to add into output string placeholders
	
	- returns: value
	*/
	private func colloquialString(unit: NSCalendarUnit, futureDate f:Bool, value: Int, relevantStr: String?, args: CVarArgType...) ->String {
		guard let bundle = self.bundle else { return "" }
		let unit_id = unit.localizedCode(value)
		let locale_time_id = (f ? "f" : "p")
		let identifier = "colloquial_\(locale_time_id)_\(unit_id)"
		
		let localized_date = withVaList(args) { (pointer: CVaListPointer) -> NSString in
			let localized = NSLocalizedString(identifier, tableName: "SwiftDate", bundle: bundle, value: "", comment: "")
			return NSString(format: localized, arguments: pointer)
		}
		
		return (relevantStr != nil ? "\(localized_date) \(relevantStr!)" : localized_date) as String
	}
	
	/**
	Get the relevant time string to append for a specified time unit difference
	
	- parameter unit unit of time
	- parameter d target date
	- parameter value value of the unit
	
	- returns: relevant time string
	*/
	private func relevantTimeForUnit(unit: NSCalendarUnit, date d: DateInRegion, value: Int) -> String? {
		if self.includeRelevantTime == false { return nil }
		guard let bundle = self.bundle else { return "" }
		
		let unit_id = unit.localizedCode(value)
		let id_relative = "relevanttime_\(unit_id)"
		let relative_localized = NSLocalizedString(id_relative, tableName: "SwiftDate", bundle: bundle, value: "", comment: "")
		if (relative_localized as NSString).length == 0 {
			return nil
		}
		let relevant_time = d.toString(DateFormat.Custom(relative_localized))
		return relevant_time
	}
	
	/**
	Get the localized string for a specified identifier string
	
	- parameter id string to search in localized bundles
	- parameter arguments arguments to add (or [] if no arguments are needed)
	
	- returns: localized string with optional arguments values filled
	*/
	private func sd_localizedString(id: String, arguments: CVarArgType...) ->String {
		guard let frameworkBundle = NSBundle(identifier: "com.danielemagutti.SwiftDate") else {
			return ""
		}
		let path = NSURL(fileURLWithPath: frameworkBundle.resourcePath!).URLByAppendingPathComponent("SwiftDate.bundle")
		guard let bundle = NSBundle(URL: path) else { return "" }
		var localized_str = NSLocalizedString(id, tableName: "SwiftDate", bundle: bundle, comment: "")
		localized_str = String(format: localized_str, arguments: arguments)
		return localized_str
	}

}

//MARK: - NSCalendarUnit Extension -

extension NSCalendarUnit {
	
	/**
	Return the localized symbols for each time unit. Singular form is 'X', plural variant is 'XX'
	
	- parameter value value of the unit unit (used to get the singular/plural variant)
	
	- returns: code in localization table
	*/
	public func localizedCode(value: Int) -> String {
		switch self {
		case NSCalendarUnit.Year: 		return (value == 1 ? "y" : "yy")
		case NSCalendarUnit.Month: 		return (value == 1 ? "m" : "mm")
		case NSCalendarUnit.WeekOfYear: return (value == 1 ? "w" : "ww")
		case NSCalendarUnit.Day: 		return (value == 1 ? "d" : "dd")
		case NSCalendarUnit.Hour: 		return (value == 1 ? "h" : "hh")
		case NSCalendarUnit.Minute: 	return (value == 1 ? "M" : "MM")
		case NSCalendarUnit.Second: 	return (value == 1 ? "s" : "ss")
		default: return ""
		}
	}
	
}

//MARK: - Supporting Structures -

/**
*  This struct encapulate the information about the difference between two dates for a specified unit of time.
*/
private struct DateFormatterValue : CustomStringConvertible {
	private var name: String
	private var value: Int
	private var separator: String
	
	private var description: String {
		return "\(value)\(separator)\(name)"
	}
}

