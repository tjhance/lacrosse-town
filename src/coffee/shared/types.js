/* @flow */

export type PuzzleState = {
  title: string,
  grid: PuzzleGrid,
  width: number,
  height: number,
  across_clues: string,
  down_clues: string,
  col_props: Array<ColProps>,
  row_props: Array<RowProps>,
};

export type PuzzleGrid = Array<Array<PuzzleCell>>;

export type PuzzleCell = {
  open: boolean,
  number: number | null,
  contents: string,
  rightbar: boolean,
  bottombar: boolean,
};

export type ColProps = {
  topbar: boolean,
};

export type RowProps = {
  leftbar: boolean,
};

export type Cursor = {
  anchor: {row: number, col: number},
  focus: {row: number, col: number},
  field_open: string,
  is_across: boolean,
  cell_field?: 'string',
};
