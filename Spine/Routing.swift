//
//  Routing.swift
//  Spine
//
//  Created by Ward van Teijlingen on 24-09-14.
//  Copyright (c) 2014 Ward van Teijlingen. All rights reserved.
//

import Foundation

/**
The RouterProtocol declares methods and properties that a router should implement.
The router is used to build URLs for API requests.
*/
public protocol RouterProtocol {
	/// The base URL of the API.
	var baseURL: NSURL! { get set }
	
	/**
	Returns an NSURL that points to the collection of resources with a given type.
	
	:param: type The type of resources.
	
	:returns: The NSURL.
	*/
	func URLForResourceType(type: ResourceType) -> NSURL
	func URLForRelationship(relationship: Relationship, ofResource resource: ResourceProtocol) -> NSURL
	func URLForQuery<T: ResourceProtocol>(query: Query<T>) -> NSURL
}

/**
The built in Router that builds URLs according to the JSON:API specification.
*/
public class Router: RouterProtocol {
	public var baseURL: NSURL! = nil

	public func URLForResourceType(type: ResourceType) -> NSURL {
		return baseURL.URLByAppendingPathComponent(type)
	}
	
	public func URLForRelationship(relationship: Relationship, ofResource resource: ResourceProtocol) -> NSURL {
		let resourceURL = resource.URL ?? URLForResourceType(resource.type).URLByAppendingPathComponent("/\(resource.id!)")
		return resourceURL.URLByAppendingPathComponent("/links/\(relationship.serializedName)")
	}

	public func URLForQuery<T: ResourceProtocol>(query: Query<T>) -> NSURL {
		var URL: NSURL!
		var preBuiltURL = false
		
		// Base URL
		if let URLString = query.URL?.absoluteString {
			URL = NSURL(string: URLString, relativeToURL: baseURL)
			preBuiltURL = true
		} else if let type = query.resourceType {
			URL = baseURL.URLByAppendingPathComponent(type, isDirectory: true)
		} else {
			assertionFailure("Cannot build URL for query. Query does not have a URL, nor a resource type.")
		}
		
		var URLComponents = NSURLComponents(URL: URL, resolvingAgainstBaseURL: true)!
		var queryItems: [NSURLQueryItem] = (URLComponents.queryItems as? [NSURLQueryItem]) ?? []
		
		// Resource IDs
		if !preBuiltURL {
			if let IDs = query.resourceIDs {
				if IDs.count == 1 {
					URLComponents.path = URLComponents.path?.stringByAppendingPathComponent(IDs.first!)
				} else {
					var item = NSURLQueryItem(name: "filter[id]", value: join(",", IDs))
					setQueryItem(item, forQueryItems: &queryItems)
				}
			}
		}
		
		// Includes
		if !query.includes.isEmpty {
			var item = NSURLQueryItem(name: "include", value: ",".join(query.includes))
			setQueryItem(item, forQueryItems: &queryItems)
		}
		
		// Filters
		for filter in query.filters {
			let item = queryItemForFilter(filter)
			setQueryItem(item, forQueryItems: &queryItems)
		}
		
		// Fields
		for (resourceType, fields) in query.fields {
			var item = NSURLQueryItem(name: "fields[\(resourceType)]", value: ",".join(fields))
			setQueryItem(item, forQueryItems: &queryItems)
		}
		
		// Sorting
		if !query.sortDescriptors.isEmpty {
			let descriptorStrings = query.sortDescriptors.map { descriptor -> String in
				if descriptor.ascending {
					return "+\(descriptor.key!)"
				} else {
					return "-\(descriptor.key!)"
				}
			}
			
			var item = NSURLQueryItem(name: "sort", value: ",".join(descriptorStrings))
			setQueryItem(item, forQueryItems: &queryItems)
		}
		
		// Pagination
		if let page = query.page {
			var item = NSURLQueryItem(name: "page", value: String(page))
			setQueryItem(item, forQueryItems: &queryItems)
		}
		
		if let pageSize = query.pageSize {
			var item = NSURLQueryItem(name: "page_size", value: String(pageSize))
			setQueryItem(item, forQueryItems: &queryItems)
		}
		
		// Compose URL
		if !queryItems.isEmpty {
			URLComponents.queryItems = queryItems
		}
		
		return URLComponents.URL!
	}
	
	/**
	Returns an NSURLQueryItem that represents the given comparison predicate in an URL.
	By default this method only supports 'equal to' predicates. You can override this method to add support for other filtering strategies.
	
	:param: filter The NSComparisonPredicate.
	
	:returns: The NSURLQueryItem.
	*/
	public func queryItemForFilter(filter: NSComparisonPredicate) -> NSURLQueryItem {
		assert(filter.predicateOperatorType == .EqualToPredicateOperatorType, "The built in router only supports Query filter expressions of type 'equalTo'")
		return NSURLQueryItem(name: "filter[\(filter.leftExpression.keyPath)]", value: "\(filter.rightExpression.constantValue)")
	}
	
	private func setQueryItem(queryItem: NSURLQueryItem, inout forQueryItems queryItems: [NSURLQueryItem]) {
		queryItems.filter { return $0.name != queryItem.name }
		queryItems.append(queryItem)
	}
}