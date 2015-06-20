NewPage = React.createClass
    render: ->
        <form action="/new" method="POST">
          <input type="text" name="title" defaultValue="" placeholder="Enter title here" />
          <input type="submit" value="Create!" />
        </form>

window.NewPage = NewPage
