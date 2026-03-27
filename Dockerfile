FROM python:3.11

WORKDIR /app

COPY . .

RUN pip install -r requirements

CMD ["python", "server_multichurch.py"]