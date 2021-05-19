/*1. � ����� ������� ������ ������ ���������?
����������� ������ � ������� airports �� ������� � ������� ������ �� ������������ �������, 
� ������� ��������� ���� airport_code ����������� ����� ������ ����.*/

select city
from airports
group by city
having count(airport_code) > 1

/*2. � ����� ���������� ���� �����, ����������� ��������� � ������������ ���������� ��������?
�������� ��������� ��� ����������� ���� �������� � ������������ ���������� ��������.
�� ������� flights ������� ������ �� ��������������� �������� ���������� ��������, 
�� ������� ������������ �������� ���� ��������.*/

select distinct departure_airport 
from flights
where aircraft_code = (
	select aircraft_code from aircrafts
	order by "range" desc
	limit 1)
	
/*3. ������� 10 ������ � ������������ �������� �������� ������.
����������� ������ ������� ����� �� �������� ������� ����������� ������� ������ 
� �������� ������ �� ����������. ����� ��������� ������ �� �����, � ������� ���� ����������� ����� ������.*/

select flight_no
from flights
where actual_departure notnull
order by (actual_departure - scheduled_departure) desc
limit 10

/*4. ���� �� �����, �� ������� �� ���� �������� ���������� ������?
��������� ����� ������ bookings � tickets �� ������ ������������, � boarding_passes �� ������ ������.
��� ��� �� ���������� left join, �� ��� ������ ������ ������� ���������, � ���� �� ��� �� ����� ���������� � ���� ������ ��������
(�� ������� ����� ��� ���������� �����), �� � ����� ������ ��������� �������� null.
����� �������, ���� ����������� ���������� � ���������� ������, �� �� ������ ����� �� ������� ���������� �����.*/

select b.book_ref
from bookings b
left join tickets t
on b.book_ref = t.book_ref
left join boarding_passes bp
on t.ticket_no = bp.ticket_no
where bp.boarding_no is null

/*5. ������� ��������� ����� ��� ������� �����, �� % ��������� � ������ ���������� ���� � ��������.
�������� ������� � ������������� ������ - ��������� ���������� ���������� ���������� ���������� �� ������� ��������� �� ������ ����. 
�.�. � ���� ������� ������ ���������� ������������� ����� - ������� ������� ��� �������� �� ������� ��������� �� ���� ��� ����� ������ ������ �� ����.
��������� bkd ���������� ���������� ���� �� ���������� �������. 
��������� sts ���������� ���������� ���� � ������������ ������ ��������.
��������� ������� flights � ��������� bkd �� flight_id, � ��������� sts �� aircraft_code.
���������� ���������� ��������� ���� ��� ������� �����.
���������� ������� ������� ��� ����������� ���������� ���������� ���������� ���������� ���������� �� ������� ��������� �� ������ ����.
���������� �� �������� departure_airport � actual_departure � ��������� �� ������� ������.*/

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

/*6. ������� ���������� ����������� ��������� �� ����� ��������� �� ������ ����������.
����������� ������ �� ������� flights �� ���� ��������. 
��� ������� ���� �������� ��������� ���������� ���������.
���������� �������� �������� �� ����� ���������� ��������� ��� ���� ����� ��������,
���������� ��� ������ ����������.*/

select aircraft_code, 
round(count(flight_id) :: numeric / (
select count(flight_id) 
from flights) :: numeric * 100, 2) as flight_ratio 
from flights
group by aircraft_code

/*7. ���� �� ������, � ������� �����  ��������� ������-������� �������, ��� ������-������� � ������ ��������?
cte_business � ���������� ��������� ������ ������-������.
cte_economy � ���������� ��������� ������ ������-������.
��������� ������� �� ���������� ������� ������-������ � ������-������ �� �������������� ����� � ��������, 
��� ��������� ������ � ������-������ ����, ��� ��������� ������ � ������-������.
������� ������������ ��������������� �������.*/

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

/*8. ����� ������ �������� ��� ������ ������?
������������� direct_flights � ���������� ���� ������� � ������������� ������� �������.
�������� ���� ���� ��������� �������, �������� ������� �� ������ � ����� �� �����.
��������� ������ � ������� ������� �� �������������.*/

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

/*9. ��������� ���������� ����� �����������, ���������� ������� �������, �������� � 
���������� ������������ ���������� ���������  � ���������, ������������� ��� �����.
������ ���������� ������� flights � airports �� ��������� ����������� � ��������� �������� ��� ��������� ���������� �� ��������� �����������/��������.
���������� ������� flights � aircrafts ��� ��������� ���������� � ��������������� ��������.
�� ������� ���������� ���������� ����� ���������� ����������� � ���������� ��������.
�������� �������� ����� ���������� �������� �������� � ����������� ����� �����������.*/

select distinct a2.city as dep_city, a.city as arr_city,
round(acos((sind(a2.latitude) * sind(a.latitude) + cosd(a2.latitude) * cosd(a.latitude) * cosd(a2.longitude - a.longitude))) :: numeric * 6371, 2) as distance, 
a3."range", a3.model, 
a3."range" - round(acos((sind(a2.latitude) * sind(a.latitude) + cosd(a2.latitude) * cosd(a.latitude) * cosd(a2.longitude - a.longitude))) :: numeric * 6371, 2) as diff
from flights f 
left join airports a on a.airport_code = f.arrival_airport
left join airports a2 on a2.airport_code = f.departure_airport
left join aircrafts a3 on a3.aircraft_code = f.aircraft_code 