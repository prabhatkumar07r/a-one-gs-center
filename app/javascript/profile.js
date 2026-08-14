document.addEventListener("turbo:load", () => {

    const buttons=document.querySelectorAll(".tab-btn")

    const panes=document.querySelectorAll(".tab-pane")

    buttons.forEach(button=>{

        button.addEventListener("click",()=>{

            buttons.forEach(btn=>btn.classList.remove("active"))

            panes.forEach(pane=>pane.classList.remove("active"))

            button.classList.add("active")

            document
                .getElementById(button.dataset.tab)
                .classList.add("active")

        })

    })

})