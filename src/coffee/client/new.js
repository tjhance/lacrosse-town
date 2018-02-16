/* @flow */

import React from 'react';

export class NewPage extends React.Component<{}> {
  render() {
    return (
      <form action="/new" method="POST">
        <input type="text" name="title" defaultValue="" placeholder="Enter title here" />
        <input type="submit" value="Create!" />
      </form>
    );
  }
}
