# This file defines the AngularJS module and configures it,
# mapping routes. Routes are
#   /new - Static page
#   /puzzle - Page where you view and edit a puzzle.
#             Controller is in controllers/puzzle.coffee

mod = angular.module 'lacrosse-town', ['ngRoute']

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
    {
        link: (scope, element, attrs) ->
            $(element[0]).keydown (event) ->
                event.stopPropagation()
    }
