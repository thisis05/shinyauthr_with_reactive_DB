## shinyauthr loginServer Customizing function 
library(DBI)

### package needed : dplyr, shiny, shinyjs, DBI


# 1. DB connection
con <- function() {
  dbConnect(SQLite(),
            dbname = "testdb.sqlite")
}

# 2. DB disconnection
discon <- function(){
  dbDisconnect(con())
}

# 3. Customize shinyauthr::loginServer

Myloginserver <-function(id, sodium_hashed = FALSE, id_col, pw_col, dbname, log_out = shiny::reactiveVal(), reload_on_logout = FALSE, cookie_logins = FALSE, sessionid_col, cookie_getter, cookie_setter) {
  
  if (cookie_logins && (missing(cookie_getter) | missing(cookie_setter) | 
                        missing(sessionid_col))) {
    stop("if cookie_logins = TRUE, cookie_getter, cookie_setter and sessionid_col must be provided")
  }
  else {
    try_class_sc <- try(class(sessionid_col), silent = TRUE)
    if (try_class_sc == "character") {
      sessionid_col <- rlang::sym(sessionid_col)
    }
  }

  data <- reactive(DBI::dbGetQuery(con(), paste0("SELECT * FROM ", dbname)))
  discon()
  
  shiny::moduleServer(id, function(input, output, session) {
    credentials <- shiny::reactiveValues(user_auth = FALSE, 
                                         info = NULL, cookie_already_checked = FALSE)
    shiny::observeEvent(log_out(), {
      if (cookie_logins) {
        shinyjs::js$rmcookie()
      }
      if (reload_on_logout) {
        session$reload()
      }
      else {
        shiny::updateTextInput(session, "password", value = "")
        credentials$user_auth <- FALSE
        credentials$info <- NULL
      }
    })
    shiny::observe({
      if (cookie_logins) {
        if (credentials$user_auth) {
          shinyjs::hide(id = "panel")
        }
        else if (credentials$cookie_already_checked) {
          shinyjs::show(id = "panel")
        }
      }
      else {
        shinyjs::toggle(id = "panel", condition = !credentials$user_auth)
      }
    })
    if (cookie_logins) {
      shiny::observeEvent(shiny::isTruthy(shinyjs::js$getcookie()), 
                          {
                            shinyjs::js$getcookie()
                          })
      shiny::observeEvent(input$jscookie, {
        credentials$cookie_already_checked <- TRUE
        shiny::req(credentials$user_auth == FALSE, is.null(input$jscookie) == 
                     FALSE, nchar(input$jscookie) > 0)
        cookie_data <- dplyr::filter(cookie_getter(), 
                                     {
                                       {
                                         sessionid_col
                                       }
                                     } == input$jscookie)
        if (nrow(cookie_data) != 1) {
          shinyjs::js$rmcookie()
        }
        else {
          .userid <- cookie_data[[]]
          .sessionid <- randomString()
          shinyjs::js$setcookie(.sessionid)
          cookie_setter(.userid, .sessionid)
          cookie_data <- utils::head(dplyr::filter(cookie_getter(), 
                                                   {
                                                     {
                                                       sessionid_col
                                                     }
                                                   } == .sessionid, {
                                                     {
                                                       id_col
                                                     }
                                                   } == .userid))
          credentials$user_auth <- TRUE
          credentials$info <- dplyr::bind_cols(dplyr::filter(data(), 
                                                             {
                                                               {
                                                                 id_col
                                                               }
                                                             } == .userid), dplyr::select(cookie_data, 
                                                                                          -{
                                                                                            {
                                                                                              id_col
                                                                                            }
                                                                                          }))
        }
      })
    }
    shiny::observeEvent(input$button, {
      
      row_username <- data()[data()[[id_col]]== input$user_name, id_col]
      
      if (length(row_username)==1) {
        row_password <- data()[data()[[id_col]]== row_username, pw_col]
        if (sodium_hashed) {
          password_match <- sodium::password_verify(row_password, 
                                                    input$password)
        }
        else {
          password_match <- identical(row_password, input$password)
        }
      }else {
        password_match <- FALSE
      }
      
      if (length(row_username) == 1 && password_match) {
        credentials$user_auth <- TRUE
        credentials$info <- data()[data()[[id_col]] == input$user_name, ]
        if (cookie_logins) {
          .sessionid <- randomString()
          shinyjs::js$setcookie(.sessionid)
          cookie_setter(input$user_name, .sessionid)
          cookie_data <- dplyr::filter(dplyr::select(cookie_getter(), 
                                                     -{
                                                       {
                                                         id_col
                                                       }
                                                     }), {
                                                       {
                                                         sessionid_col
                                                       }
                                                     } == .sessionid)
          if (nrow(cookie_data) == 1) {
            credentials$info <- dplyr::bind_cols(credentials$info, 
                                                 cookie_data)
          }
        }
      }
      else {
        shinyjs::toggle(id = "error", anim = TRUE, time = 1, 
                        animType = "fade")
        shinyjs::delay(5000, shinyjs::toggle(id = "error", 
                                             anim = TRUE, time = 1, animType = "fade"))
      }
    })
    shiny::reactive({
      shiny::reactiveValuesToList(credentials)
    })
  })
}