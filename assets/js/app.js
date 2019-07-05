// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import dependencies
//
import "phoenix_html"

// Import local files
//
// Local files can be imported directly using relative paths, for example:
// import socket from "./socket"
import React from 'react'
import ReactDOM from 'react-dom'

import css from "../css/app.css"

import Index from './index.js'

ReactDOM.render(<Index />, document.getElementById('mountPoint'))
