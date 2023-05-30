library(shiny);library(DBI);library(shinydashboard);library(RSQLite);library(shinyauthr);library(shinyjs);library(shinyWidgets)
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

# Define server logic required to draw a histogram
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

# Run the application 
shinyApp(ui = ui, server = server)
