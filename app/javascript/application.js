import "@hotwired/turbo-rails"
import "controllers"

import * as bootstrap from "bootstrap"

import "notification"
import "chartkick"
import { Chart } from "chart.js"

window.Chart = Chart
window.bootstrap = bootstrap

import "custom"
import "header"
import "profile"
import "./student_header"