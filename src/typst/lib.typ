#let default_image_path = "/src/typst/1.jpeg"
#let default_weekday_names = ([Sun], [Mon], [Tue], [Wed], [Thu], [Fri], [Sat])
#let read_syukujitsu_csv() = {
  let csv = csv("/src/typst/syukujitsu.csv")
  let result = (:)
  for row in csv {
    result.insert(row.at(0), row.at(1))
  }
  result
}

#let month_calendar_table(
  year, month, holiday_data: (:), weekday_names: default_weekday_names,
) = {
  let month_day_1 = datetime(
    year: year,
    month: month,
    day: 1,
  )

  let days = range(0, 31)
    .map(day => month_day_1 + duration(days: day))
    .filter(day => day.month() == month)

  let first_day_padding = calc.rem-euclid(
    int(days.first().display("[weekday repr:monday]")),
    7
  )

  let cal_grid = grid(
    columns: (1fr,) * 7,
    rows: (3em,) + (1fr,) * 6,
    inset: 1em,
    // fill: rgb(200, 200, 255),
    // fill: rgb(255, 255, 255, 80%),
    ..weekday_names.map(name => {
      let color = if name == weekday_names.at(0) {
        // Sunday
        red
      } else if name == weekday_names.at(6) {
        // Saturday
        blue
      } else {
        black
      }
      let weekday_name = place(top + center)[
        #text(name, fill: color, size: 1.5em, weight: "black")
      ]
      grid.cell(weekday_name, stroke: (bottom: 1pt))
    }),
    ..(([], ) * first_day_padding),
    ..days.map(day => {
      // y/m/d or y-m-d
      let holiday_name = holiday_data.at(day.display("[year]/[month padding:none]/[day padding:none]"), default: "")
      let holiday_name =  if holiday_name == "" {
        holiday_data.at(day.display("[year]-[month padding:none]-[day padding:none]"), default: "")
      } else {
        holiday_name
      }

      let color = if holiday_name != "" {
        // green
        // rgb("#207ef2c")
        rgb("#00B000")
      } else if day.weekday() == 6 {
        blue
      } else if day.weekday() == 7 {
        red
      }  else {
        black
      }
      let day_num = day.display("[day padding:none]")
      place(top + left)[
        #text(fill: color, size: 2em, weight: "bold")[
          #day_num 
        ]
        #linebreak()
        #text(fill: color, size: 0.8em, weight: "bold")[
          #holiday_name
        ]
      ]
    })
  )

  let rect = rect(inset: 0.5pt, radius: 10pt, fill: rgb(255, 255, 255, 80%),)[
    #cal_grid
  ]


  rect
}

#let month_calendar(year, month, image, title: "[year] Calendar", holiday_data: (:), weekday_names: default_weekday_names, month_format: "[month repr:long]") = {
  let month_datetime = datetime(year: year, month: month, day: 1)

  box(clip: true)[
    #image
  ]

  v(1fr)
  place(bottom)[
    #box(height: 50%, width: 100%)[
      #place(top + left)[
        #pad(1em)[
          #month_calendar_table(year, month, holiday_data: holiday_data, weekday_names: weekday_names)
        ]
      ]
    ]
  ]
  v(1fr)

  let half_upper = box(height: 50%, width: 100%)[
    #place(bottom + right, dy: -3em, dx: -2em)[
        #text(size: 7em, weight: "black", fill: white)[#month_datetime.display(month_format)]
    ]
  ]

  place(top)[
    #half_upper
  ]

  place(bottom + center, dy: -2em)[
    #text()[
      #datetime(year: year, month: month, day: 1).display(title)
    ]
  ]
}

#let quadruple_image(path1, path2, path3, path4) = {
  grid(
    columns: (1fr, 1fr),
    rows: (1fr, 1fr),
    image(path1, width: 100%, height: 100%, fit: "cover"),
    image(path2, width: 100%, height: 100%, fit: "cover"),
    image(path3, width: 100%, height: 100%, fit: "cover"),
    image(path4, width: 100%, height: 100%, fit: "cover"),
  )
}

#let double_image(path1, path2) = {
  grid(
    columns: (1fr, 1fr),
    image(path1, width: 100%, height: 100%, fit: "cover"),
    image(path2, width: 100%, height: 100%, fit: "cover"),
  )
}
#let single_image(path) = {
    image(path, width: 100%, height: 100%, fit: "cover")
}

#let vstack(content) = {
  stack(
    dir: ttb,
    spacing: none,
    content,
  )
}

#let half_area(grid) = {
  box(height: 50%)[
    #grid
  ]
}

#let full_area(grid) = {
  box(height: 100%)[
    #grid
  ]
}

#let year_calendar(
  year, 
  months: range(1, 12 + 1),
  font: "",
  images: (),
  weekday_names: default_weekday_names,
  holiday_data: read_syukujitsu_csv(),
  title: "[year] Calendar",
  month_names: range(1, 12 + 1).map(month => datetime(year: 0, month: month, day: 1).display("[month repr:long]")),
) = [
  #set text(font: font)
  #set page(margin: 0pt)
  #show box: it => align(it, center)

  #for month in months [
    #month_calendar(year, month, images.at(month - 1, default: half_area(single_image(default_image_path))), holiday_data: holiday_data, weekday_names: weekday_names, title: title, month_format: month_names.at(month - 1, default: "[month repr:long]"))

    #pagebreak(weak: true)
  ]

]

// ---------------------

#set page(margin: 0pt)

#import sys: inputs

#year_calendar(
  2025,
  font: "Noto Sans JP",
  month_names: range(1, 12 + 1).map(month => str(month) + "月"),
  weekday_names: ([日], [月], [火], [水], [木], [金], [土]),
  images: (
    half_area(single_image(inputs.at("jan", default: "/src/typst/1.jpeg"))),
    half_area(single_image(inputs.at("feb", default: "/src/typst/1.jpeg"))),
    half_area(single_image(inputs.at("mar", default: "/src/typst/1.jpeg"))),
    half_area(single_image(inputs.at("apr", default: "/src/typst/1.jpeg"))),
    half_area(single_image(inputs.at("may", default: "/src/typst/1.jpeg"))),
    half_area(single_image(inputs.at("jun", default: "/src/typst/1.jpeg"))),
    half_area(single_image(inputs.at("jul", default: "/src/typst/1.jpeg"))),
    half_area(single_image(inputs.at("aug", default: "/src/typst/1.jpeg"))),
    half_area(single_image(inputs.at("sep", default: "/src/typst/1.jpeg"))),
    half_area(single_image(inputs.at("oct", default: "/src/typst/1.jpeg"))),
    half_area(single_image(inputs.at("nov", default: "/src/typst/1.jpeg"))),
    half_area(single_image(inputs.at("dec", default: "/src/typst/1.jpeg"))),
  ),
)
