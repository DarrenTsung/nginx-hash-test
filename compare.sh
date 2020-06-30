function replace_and_reload_with_nginx() {
    sed -i '' "s/$1/$2/g" nginx.conf
    docker-compose exec load-balancer "nginx" "-s" "reload" > /dev/null
    sleep 0.2
}

function run_requests_with_uuids() {
    ./request.sh zL9h2Mjwzy TFXhHud29A r46EJTnpwB sP2JubDKQc KrXz2KkuPn IZSvxNIgHX WQlZodeZWa MYYcHfLoHE qK4RfBVxtw L8fzjepkpx ItLYnkt5s2 ZJ4UkhFv8w gAHvYQHWBI F7n22S1Pq5 II34P7mpwy JefycPfwuD RIdQGc2H5W f2Bi2VfyW0 uP8Hh2Rb0H 8UsA6WiMGP
}

function check_routes_after_switch() {
    # Make sure that initial configuration is pointing to [web-1, web-2].
    replace_and_reload_with_nginx web-3 web-2

    # Run requests for all these file paths.
    run_requests_with_uuids | sort > before-reload.txt

    # Replace web-2 with web-3 and reload nginx.
    replace_and_reload_with_nginx web-2 web-3

    # Run requests with new server pool [web-1, web-3].
    run_requests_with_uuids | sort > after-reload.txt

    # Show the changes between routes before and after.
    diff --side-by-side --suppress-common-lines --width 60 before-reload.txt after-reload.txt

    # If any of the lines contain web-1, then a route that was previously routing to web-1 
    # is routing to a different server, or vise-versa.
    local NUM_WEB_1_PRESENT=$(diff --side-by-side --suppress-common-lines --width 60 before-reload.txt after-reload.txt | rg 'web-1' | wc -l | xargs)
    if (( $NUM_WEB_1_PRESENT > 0 )); then
        echo "Found routes that either previously went to web-1 or are now routed to web-1!"
    else
        echo "Reload successful, all previous routes to web-1 stayed routing to web-1, only changed routes involved web-2 / web-3."
    fi
}

# Make sure that hash configuration is set to consistent at first. 
replace_and_reload_with_nginx "hash \$key;" "hash \$key consistent;"

echo "With consistent hashing:"
check_routes_after_switch

echo ""

# Change hash configuration to not use consistent.
replace_and_reload_with_nginx "hash \$key consistent;" "hash \$key;" 

echo "Without consistent hashing:"
check_routes_after_switch