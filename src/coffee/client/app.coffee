# This file defines the AngularJS module and configures it,
# mapping routes. Routes are
#   /new - Static page
#   /puzzle - Page where you view and edit a puzzle.
#             Controller is in controllers/puzzle.coffee

mod = angular.module 'lacrosse-town', ['ngRoute', 'editableDivUtil']

mod.config ($routeProvider, $locationProvider) ->
    $routeProvider.when '/new', {
        templateUrl: '/static/angular/home.html'
    }
    $routeProvider.when '/puzzle/:puzzle_id', {
        templateUrl: '/static/angular/puzzle.html'
        controller: puzzleController
    }
    $locationProvider.html5Mode true

# Add a directive which focuses on an input element and selects
# the text (setting it to the given value)
mod.directive 'focusAndSelect', () ->
    {
        link: (scope, element, attrs) ->
            element[0].value = attrs.focusAndSelect
            element[0].select()
    }

# A directive which prevents a keydown event from bubbling up
# the DOM. Useful if you're focused on a textfield and you want
# your keypress to avoid going up to the body where it will
# perform an action on the grid.
mod.directive 'dontBubbleKeydown', () ->
    link: (scope, element, attrs) ->
        $(element[0]).keydown (event) ->
            event.stopPropagation()

#mod.directive 'contenteditable', () ->
#    {
#        require: 'ngModel'
#        link: (scope, element, attrs, ngModel) ->
#            ngModel.$render = () ->
#                console.debug "moo"
#                element.html ngModel.$viewValue or ""
#
#            element.on 'blur keyup change', () ->
#                scope.$apply read
#
#            read = () ->
#                html = element.html()
#                ngModel.$setViewValue html
#
#            read()
#
#            escapeHTML = (txt) ->
#                $('<div/>').text(txt).html()
#
#            ngModel.$formatters.push (value) ->
#                ("<div>#{escapeHTML txt}</div>" for txt in value.split "\n").join ""
#            ngModel.$parsers.push (html) ->
#                ($(elem).text() for elem in $("<div>#{html}</div>").children().get()).join "\n"
#    }

#mod.directive 'contenteditablelist', () ->
#    {
#        restrict: 'E'
#        transclude: true
#        replace: true
#        template: '<div contenteditable="true"></div>'
#        require: ['ngModel']
#        compile: (tElement, tAttr, _) -> (scope, iElement, iAttrs, controller, transcludeFn) ->
#            elemString = iAttrs.ltIter
#            collectionString = iAttrs.ngModel
#            cursorString = iAttrs.ltCursor
#            #setContents = ($parse iAttrs.ltContents).assign
#
#            elements = []
#
#            #iElement.html
#
#            selectRanges = null
#            onUserAction = () ->
#                for elem in elements
#                    
#
#                selectRanges = []
#                for range in rangy.getSelection().getRanges()
#                    cont1 = range.startContainer()
#                    cont2 = range.endContainer()
#                    if cont1.lt_containing_editable? and cont1.lt_containing_editable == iElement
#                        selectRanges.push {
#                            index1: cont1.lt_index
#                            offset1: range.startOffset()
#                            index2: cont2.lt_index
#                            offset2: range.endOffset()
#                        }
#
#            $(iElement).keyup onUserAction
#            $(iElement).mouseup onUserAction
#
#            scope.$watchCollection collectionString, (collection) ->
#                # TODO optimize
#
#                for element in elements
#                    element.element.remove()
#                    element.scope.$destroy()
#                elements = []
#
#                for i in [0 ... collection.length]
#                    do (i) ->
#                        collection_object = collection[i]
#                        childScope = scope.$new()
#                        childScope[elemString] = collection_object
#                        childScope.$index = i
#
#                        transcludeFn childScope, (childElem) ->
#                            childElem.lt_containing_editable = iElement
#                            childElem.lt_index = i
#                            elements.push {element: childElem, scope: childScope}
#                            iElement.append childElem
#
#                #switch cursor_desc.length
#                #    when 0
#                #        iElement.blur()
#                #    when 2
#                #        row1 = cursor_desc[0].row
#                #        pos1 = cursor_desc[0].pos
#                #        row2 = cursor_desc[1].row
#                #        pos2 = cursor_desc[1].pos
#
#                #        iElement.focus()
#                #        range = document.createRange()
#                #        range.setStart elements[row1].element, pos1
#                #        range.setEnd elements[row2].element, pos2
#
#                #        sel = window.getSelection()
#                #        sel.removeAllRanges()
#                #        sel.addRange range
#}
