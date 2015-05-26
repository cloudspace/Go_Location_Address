package main // import "github.com/cloudspace/Go_Location_Address"

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strconv"

	_ "github.com/lib/pq"
)

func main() {
	if len(os.Args) != 3 {
		fmt.Println(errorStringAsJSON(fmt.Sprintf("Must have 2 argument: your are passing %v arguments", len(os.Args)-1)))
		return
	}

	strLat := os.Args[1]
	strLng := os.Args[2]

	lat, err := strconv.ParseFloat(strLat, 64)

	if err != nil {
		fmt.Println(getJSONError(err))
		return
	}

	lng, err := strconv.ParseFloat(strLng, 64)

	if err != nil {
		fmt.Println(getJSONError(err))
		return
	}

	cmd := exec.Command("sh", "-c", "service postgresql start")
	err = cmd.Run()

	if err != nil {
		fmt.Println(getJSONError(err))
		return
	}

	connectionURI := "host=127.0.0.1 port=5432 user=docker password=docker dbname=postgres"
	//fmt.Println("Connecting")
	db, err := sql.Open("postgres", connectionURI)
	if err != nil {
		fmt.Println(getJSONError(err))
		return
	}
	defer db.Close()

	query := fmt.Sprintf("SELECT ST_GeometryFromText('POINT(%f %f)', 4269) as the_geom", lng, lat)
	result, err := queryPostgres(query, db)
	if err != nil {
		fmt.Println(getJSONError(err))
		return
	}

	if len(result) == 0 {
		err = fmt.Errorf("No results from query: %s", query)
		fmt.Println(getJSONError(err))
		return
	}

	geomLocation := result[0]["the_geom"]
	//fmt.Println(fmt.Sprintf("Got location: %s", geomLocation))

	query = fmt.Sprintf("SELECT * from tiger_data._addrfeat WHERE ST_DWithin(the_geom, E'%s', 0.2) ORDER BY ST_Distance(the_geom, E'%s') limit 1;", geomLocation, geomLocation)
	result, err = queryPostgres(query, db)
	if err != nil {
		fmt.Println(getJSONError(err))
		return
	}

	if len(result) == 0 {
		jsonResponse := make(map[string]interface{}, 0)
		jsonResponse["address"] = ""
		jsonResponse["error"] = ""
		fmt.Println(asJSON(jsonResponse))
		return
	}

	geomAddress := result[0]["the_geom"]
	fromRightHouseNumber := result[0]["rfromhn"]
	toRightHouseNumber := result[0]["rtohn"]
	fromLeftHouseNumber := result[0]["lfromhn"]
	toLeftHouseNumber := result[0]["ltohn"]
	fullName := result[0]["fullname"]

	fromHouseNumber := fromRightHouseNumber
	toHouseNumber := toRightHouseNumber

	hasBothHouseNumbers := toLeftHouseNumber != nil && toRightHouseNumber != nil
	hasAtLeastOneNumber := toLeftHouseNumber != nil || toRightHouseNumber != nil
	skipAddressNum := false
	if hasBothHouseNumbers {
		query = fmt.Sprintf("SELECT E'%s' &< st_closestpoint(E'%s', E'%s') as houseIsOnLeft", geomLocation, geomAddress, geomLocation)
		result, err = queryPostgres(query, db)

		if err != nil {
			fmt.Println(getJSONError(err))
			return
		}

		if len(result) == 0 {
			err = fmt.Errorf("No results from query: %s", query)
			fmt.Println(getJSONError(err))
			return
		}

		houseIsOnLeft := result[0]["houseisonleft"].(bool)
		if houseIsOnLeft {
			//fmt.Println("House is on left")
			fromHouseNumber = fromLeftHouseNumber
			toHouseNumber = toLeftHouseNumber
		}

	} else if hasAtLeastOneNumber {
		if toLeftHouseNumber != nil {
			fromHouseNumber = fromLeftHouseNumber
			toHouseNumber = toLeftHouseNumber
		}
	} else {
		skipAddressNum = true
	}

	jsonResponse := make(map[string]interface{}, 0)
	jsonResponse["address"] = ""
	jsonResponse["error"] = ""

	if skipAddressNum {
		jsonResponse["address"] = fullName
	} else {
		query = fmt.Sprintf("SELECT %s + CAST( @(%s - %s) * ST_Line_Locate_Point(E'%s', E'%s') As integer) As street_num", fromHouseNumber, fromHouseNumber, toHouseNumber, geomAddress, geomLocation)
		result, err = queryPostgres(query, db)
		if err != nil {
			fmt.Println(getJSONError(err))
			return
		}

		if len(result) > 0 {
			streetNumber := result[0]["street_num"]
			jsonResponse["address"] = fmt.Sprintf("%d %s", streetNumber, fullName)
		}
	}

	fmt.Println(asJSON(jsonResponse))
}

func queryPostgres(sqlString string, db *sql.DB) ([]map[string]interface{}, error) {
	rows, err := db.Query(sqlString)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	columns, err := rows.Columns()
	if err != nil {
		return nil, err
	}
	count := len(columns)
	var tableData []map[string]interface{}
	values := make([]interface{}, count)
	valuePtrs := make([]interface{}, count)
	for rows.Next() {
		for i := 0; i < count; i++ {
			valuePtrs[i] = &values[i]
		}
		rows.Scan(valuePtrs...)
		entry := make(map[string]interface{})
		for i, col := range columns {
			var v interface{}
			val := values[i]
			b, ok := val.([]byte)
			if ok {
				v = string(b)
			} else {
				v = val
			}
			entry[col] = v
		}
		tableData = append(tableData, entry)
	}
	return tableData, nil
}

func asJSON(anything interface{}) string {

	jsonData, err := json.Marshal(anything)
	if err != nil {
		return getJSONError(err)
	}
	return string(jsonData)
}

func getJSONError(myError error) string {

	errorJSON := make(map[string]interface{})
	errorJSON["error"] = myError.Error()
	errorJSON["address"] = ""
	jsonData, err := json.Marshal(errorJSON)
	if err != nil {
		return errorStringAsJSON("There was an error generatoring the error.. goodluck")
	}
	return string(jsonData)
}

func errorStringAsJSON(errorString string) string {

	return "{\"address\": \"\"\n\"error\": \"" + errorString + "\"}"
}
