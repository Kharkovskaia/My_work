/*1. В каких городах больше одного аэропорта?
Сгруппируем данные в таблице airports по городам и выведем только те наименования городов, 
в которых первичный ключ airport_code встречается более одного раза.*/

select city
from airports
group by city
having count(airport_code) > 1

/*2. В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета?
Выполним подзапрос для определения кода самолета с максимальной дальностью перелета.
Из таблицы flights выберем только те неповторяющиеся значения аэропортов прибытия, 
из которых отправляются указанны коды самолета.*/

select distinct departure_airport 
from flights
where aircraft_code = (
	select aircraft_code from aircrafts
	order by "range" desc
	limit 1)
	
/*3. Вывести 10 рейсов с максимальным временем задержки вылета.
Отсортируем список номеров рейса по убыванию разницы фактической времени вылета 
и временем вылета по расписанию. Будем учитывать только те рейсы, у которых есть фактическое время вылета.*/

select flight_no
from flights
where actual_departure notnull
order by (actual_departure - scheduled_departure) desc
limit 10

/*4. Были ли брони, по которым не были получены посадочные талоны?
Объединим днные таблиц bookings и tickets по номеру бронирования, и boarding_passes по номеру билета.
Так как мы используем left join, то все данные первой таблицы останутся, а если по ним не будет совпадения в двух других таблицах
(не получен билет или посадочный талон), то в такие ячейки запишется значение null.
Таким образом, если отсутствует информация о посадочном талоне, то по данной брони не получен посадочный талон.*/

select b.book_ref
from bookings b
left join tickets t
on b.book_ref = t.book_ref
left join boarding_passes bp
on t.ticket_no = bp.ticket_no
where bp.boarding_no is null

/*5. Найдите свободные места для каждого рейса, их % отношение к общему количеству мест в самолете.
Добавьте столбец с накопительным итогом - суммарное накопление количества вывезенных пассажиров из каждого аэропорта на каждый день. 
Т.е. в этом столбце должна отражаться накопительная сумма - сколько человек уже вылетело из данного аэропорта на этом или более ранних рейсах за день.
Подзапрос bkd определяет количество мест по посадочным талонам. 
Подзапрос sts определяет количество мест в определенной модели самолета.
Соединяем таблицу flights и подзапрос bkd по flight_id, и подзапрос sts по aircraft_code.
Определяем количество свободных мест для каждого рейса.
Используем оконную функцию для определения суммарного накопления количества вывезенных пассажиров из каждого аэропорта на каждый день.
Группируем по столбцам departure_airport и actual_departure и сортируем по моменту вылета.*/

select f.departure_airport, date(f.actual_departure), f.flight_id, 
sts.seats_cnt - bkd.seats_booked as empty_seats,
round(((sts.seats_cnt - bkd.seats_booked)::numeric/sts.seats_cnt)*100, 2) as percent_empty_seats,
bkd.seats_booked,
sum(bkd.seats_booked) over (partition by  date(f.actual_departure), f.departure_airport order by f.actual_departure) as cum_total_seats
from flights f 
join (select f.flight_id, count(bp.seat_no) as seats_booked
	from boarding_passes bp 
	join flights f on f.flight_id = bp.flight_id 
	group by f.flight_id) as bkd
on f.flight_id = bkd.flight_id
join (select s.aircraft_code, count(*) as seats_cnt 
	from seats s 
	group by s.aircraft_code) as sts
on sts.aircraft_code = f.aircraft_code

/*6. Найдите процентное соотношение перелетов по типам самолетов от общего количества.
Сгруппируем данные из таблицы flights по коду самолета. 
Для каждого кода самолета определим количество перелетов.
Полученное значение разделим на общее количество перелетов для всех типов самолета,
полученное при помощи подзапроса.*/

select aircraft_code, 
round(count(flight_id) :: numeric / (
select count(flight_id) 
from flights) :: numeric * 100, 2) as flight_ratio 
from flights
group by aircraft_code

/*7. Были ли города, в которые можно  добраться бизнес-классом дешевле, чем эконом-классом в рамках перелета?
cte_business – определяет стоимость билета бизнес-класса.
cte_economy – определяет стоимость билета эконом-класса.
Соединяем таблицы со стоимостью билетов бизнес-класса и эконом-класса по идентификатору рейса с условием, 
что стоимость билета в эконом-классе выше, чем стоимость билета в бизнес-классе.
Выведем наименование соответствующих городов.*/

with cte_business as (
	select tf.flight_id, tf.ticket_no, tf.amount 
	from ticket_flights tf 
	where tf.fare_conditions = 'Business'),
cte_economy as (
	select tf.flight_id, tf.ticket_no, tf.amount 
	from ticket_flights tf 
	where tf.fare_conditions = 'Economy')
select distinct a.city
from cte_business b
join cte_economy  e on b.flight_id = e.flight_id and e.amount > b.amount
join flights f on b.flight_id = f.flight_id 
join airports a on f.arrival_airport = a.airport_code

/*8. Между какими городами нет прямых рейсов?
Представление direct_flights – уникальные пары городов с существующими прямыми рейсами.
Получаем пары всех возможных городов, исключая перелет из города в такой же город.
Исключаем записи с прямыми рейсами из представления.*/

create view direct_flights as
	select a1.city dep_city, a2.city arr_city
	from flights f 
	join airports a1 on f.departure_airport = a1.airport_code 
	join airports a2 on f.arrival_airport = a2.airport_code
	group by dep_city, arr_city
	
select a1.city dep_city, a2.city arr_city
from airports a1, airports a2 
where a1.city != a2.city 
except 
select df.dep_city, df.arr_city 
from direct_flights df 

/*9. Вычислите расстояние между аэропортами, связанными прямыми рейсами, сравните с 
допустимой максимальной дальностью перелетов  в самолетах, обслуживающих эти рейсы.
Дважды объединяем таблицы flights и airports по аэропорту отправления и аэропорту прибытия для получения информации об аэропорте отправления/прибытия.
Объединяем таблицы flights и aircrafts для получения информации о характеристиках самолета.
По формуле определяем расстояние между аэропортом отправления и аэропортом прибытия.
Получаем разность между дальностью перелета самолета и расстоянием между аэропортами.*/

select distinct a2.city as dep_city, a.city as arr_city,
round(acos((sind(a2.latitude) * sind(a.latitude) + cosd(a2.latitude) * cosd(a.latitude) * cosd(a2.longitude - a.longitude))) :: numeric * 6371, 2) as distance, 
a3."range", a3.model, 
a3."range" - round(acos((sind(a2.latitude) * sind(a.latitude) + cosd(a2.latitude) * cosd(a.latitude) * cosd(a2.longitude - a.longitude))) :: numeric * 6371, 2) as diff
from flights f 
left join airports a on a.airport_code = f.arrival_airport
left join airports a2 on a2.airport_code = f.departure_airport
left join aircrafts a3 on a3.aircraft_code = f.aircraft_code 