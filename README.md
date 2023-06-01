# shinyauthr with reactive DB in R Shiny

**This is the example of `how to use shinyauthr with reactive DB in R Shiny`**


## Packages
`shinyauthr` `shiny` `shinydashboard` `shinyWidgets` `DBI` `RSQLite`

**At First, you have to check how to use [`shinyauthr`](https://github.com/PaulC91/shinyauthr)**

## Usage

### 1. DB (SQLite) 

(This code is optimized for `SQLite`. If you are using a different DBMS, you can modify the code in `MyloginServer.R`)

#### (1) create DB

First, create a database and table to store user information. Please refer to the `createDB.R` file to perform this task.
```
library(RSQLite);library(DBI)

# 1. create DB 
connectDB <- dbConnect(SQLite(), dbname = "testdb.sqlite")

# 2. create table 
DBI::dbExecute(connectDB, "CREATE TABLE test (
                                 id VARCHAR(20) PRIMARY KEY,
                                 pw VARCHAR(20))")
```
#### (2) make connection / disconnection function

```
library(RSQLite);library(DBI)

# 1. DB connection
con <- function() {
  dbConnect(SQLite(),
            dbname = "testdb.sqlite")
}

# 2. DB disconnection
discon <- function(){
  dbDisconnect(con())
}
```


### 2. `shinyauthr::loginServer` Customizing : `MyloginServer`

Explanation of the modified code versus original `loginServer` (details in `MyloginServer.R`).

#### (1) Parameter

`id` : An ID string that corresponds with the ID used to call the module's UI function

`id_col` : ID column name of your DB

`pw_col` : PassWord column name of your DB

`dbname` : Your DB name

`sodium_hashed` : have the passwords been hash encrypted using the sodium package? defaults to FALSE

`log_out` : [reactive] supply the returned reactive from logoutServer here to trigger a user logout

`reload_on_logout` : should app force a session reload on logout?

else : `cookie_logins` `sessionid_col` `cookie_getter` `cookie_setter`

**check [`shinyauthr`](https://github.com/PaulC91/shinyauthr) about the cookie settings**

#### (2) Change

1. `data` : user info DB
```
data <- reactive(DBI::dbGetQuery(con(), paste0("SELECT * FROM ", dbname)))
```
2. `row_username` : id (user input) 
```
 row_username <- data()[data()[[id_col]]== input$user_name, id_col]
```
3. `row_password` : password (user input)
```
row_password <- data()[data()[[id_col]]== row_username, pw_col]
```
4. `credential$info : authenticated users information
```
credentials$info <- data()[data()[[id_col]] == input$user_name, ]
```

So, you can call `MyloginServer` function like this in this example case
```
credentials <- Myloginserver(
    id = "login",
    id_col = "id",
    pw_col = "pw",
    dbname = "test",
    log_out = reactive(logout_init()),
    reload_on_logout = TRUE
    # additional cookie settings
  )
```
### 3. Shiny app

#### (1) UI

```
library(shiny);library(DBI);library(shinydashboard);library(RSQLite);library(shinyauthr);library(shinyWidgets)
source("MyloginServer.R")


# Define UI for application that draws a histogram
ui <- dashboardPage(
  skin = "black",
  header = dashboardHeader(
    tags$li(class = "dropdown", style = "padding: 8px;", shinyauthr::logoutUI("logout"))
  ),
  
  sidebar = dashboardSidebar(
    sidebarMenu(
      id = "tabs",
      menuItem(htmlOutput("infotabname"), tabName = "info", selected = T)
    )
  ),
  
  body = dashboardBody(
    shinyauthr::loginUI("login",
                        title = "Please log in", 
                        user_title = "ID", 
                        pass_title = "PASSWORD", 
                        login_title = "Log in",
                        error_message = "Not available",
                        additional_ui = tags$a(
                          shinyWidgets::actionBttn(
                            inputId = "register",
                            label = "Register",
                            style = "fill", 
                            color = "danger",
                            size = "xs"
                          )
                        )
    ),
    
    tabItems(
      tabItem(tabName = "info",
              uiOutput("success_ui")
      )
    )
  )
)
```
When Using `shinydashboard`,  You should write `loginUI` function in `dashboradBody`. To display the `logoutUI` at the top right corner of the Shiny Web page, you can write the code in 'dashboardHeader' using `tags$il`.

`Shinyauthr::loginUI` does not have any Register option, so you'd make additional UI if you want using `addtional_ui` parameter. 

#### (2) Server

```
server <- function(input, output) {

  # login / log out function --------------------------------------------------
  
  # 1. credentials 
  credentials <- Myloginserver(
    id = "login",
    id_col = "id",
    pw_col = "pw",
    dbname = "test",
    log_out = reactive(logout_init()),
    reload_on_logout = TRUE
  )
  
  # 2. when log out 
  logout_init <- shinyauthr::logoutServer( 
    "logout", 
    reactive(credentials()$user_auth)
  )
  
  # 3. current user information
  
  userdata <- reactive({
    credentials()$info
  })
  
  #----------------------------------------------------------------------------
  
  output$infotabname <- renderText({
    if(credentials()$user_auth){
      return(HTML("connected"))
    }else{
      return(HTML("disconnected"))
    }
  })
  
  output$success_ui <- renderUI({
    req(credentials()$user_auth)
    tableOutput("user_info")
  })
  
  output$user_info <- renderTable({
    userdata()
  })
  
  observeEvent(input$register, {
    showModal(
      modalDialog(
        easyClose = FALSE,
        fluidRow(width = 12, 
                 column(width = 12,
                        title = "Welcome!",
                        br(),
                        textInput("id", "ID"),
                        textInput("pw", "PASSWORD"),
                        br())),
        footer = fluidRow(width = 12,
                          shinyWidgets::actionBttn("register_success", "success", color = "success", style = "fill", size = "xs"),
                          shinyWidgets::actionBttn("register_cancel", "cancel", color = "danger", style = "fill", size = "xs"), 
                          br())
      )
    )
  })
  
  observeEvent(input$register_success, {
    tryCatch(
      {
        DBI::dbExecute(con(), "INSERT INTO test values (?, ?)", c(input$id, input$pw))
        removeModal()
      },
      error = function(e) {
        if (grepl("UNIQUE constraint failed", e$message)) {
          showModal(modalDialog("Change your ID. Already exists", easyClose = T))
        } else {
          stop(e)
        }
      }
    )
  })
  
  observeEvent(input$register_cancel, {
    removeModal()
  })

}
```

If a user successfully logs in, `credentials()$user_auth == TRUE`. Therefore, if you want to show a Tab only after the login is completed, you need to set it for each UI using `req(credentials()$user_auth)` option.
In addition, `credentials()$info` will hold the values of each column in the login DB as variables once the login is completed.
The logic of this example is as follows:

1. User registration
2. Save the registration information into the DB
3. Log in with the registered information
4. check and verify DB information reactively upon login 
5, If the login is successful, check `credentials()$user_auth == TRUE` and render UI


### 4. Example 

(1) log in UI

<img width="1271" alt="image" src="https://github.com/thisis05/shinyauthr_with_reactive_DB/assets/118661725/1af8b9f8-dc28-4bc9-85fa-74192634383d">

(2) Register

<img width="1273" alt="image" src="https://github.com/thisis05/shinyauthr_with_reactive_DB/assets/118661725/98f96af5-a2a6-4703-8be9-b1b2907c3cc6">

(3) After log in

<img width="1261" alt="image" src="https://github.com/thisis05/shinyauthr_with_reactive_DB/assets/118661725/a7bd31a6-88a9-4be4-9824-422a4063ba91">

  
